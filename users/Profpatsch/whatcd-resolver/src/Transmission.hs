{-# LANGUAGE QuasiQuotes #-}

module Transmission where

import AppT
import Builder
import Control.Monad.Logger.CallStack
import Control.Monad.Reader
import Data.Aeson qualified as Json
import Data.Aeson.BetterErrors qualified as Json
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Error.Tree
import Data.HashMap.Strict qualified as HashMap
import Data.List qualified as List
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict qualified as Map
import Database.PostgreSQL.Simple (Only (..))
import Database.PostgreSQL.Simple.Types (PGArray (PGArray))
import FieldParser (FieldParser' (..))
import FieldParser qualified as Field
import Html qualified
import Http qualified
import Json qualified
import Json.Enc (Enc)
import Json.Enc qualified as Enc
import Label
import MyPrelude
import Network.HTTP.Types
import OpenTelemetry.Trace qualified as Otel hiding (getTracer, inSpan, inSpan')
import Optional
import Postgres.MonadPostgres
import Pretty
import Text.Blaze.Html (Html)
import UnliftIO
import Prelude hiding (span)

-- | A value between (inclusive) 0% and (inclusive) 100%. Precise to 1% steps.
newtype Percentage = Percentage {unPercentage :: Int}
  deriving stock (Show)

-- | Parse a scientific into a Percentage
scientificPercentage :: FieldParser' Error Scientific Percentage
scientificPercentage =
  Field.boundedScientificRealFloat @Float
    >>> ( FieldParser $ \f ->
            if
              | f < 0 -> Left "percentage cannot be negative"
              | f > 1 -> Left "percentage cannot be over 100%"
              | otherwise -> Right $ Percentage $ ceiling (f * 100)
        )

-- | Fetch the current status from transmission,
--  and remove the transmission hash and torrent file from our database iff it does not exist in transmission anymore
getAndUpdateTransmissionTorrentsStatus ::
  ( MonadTransmission m,
    MonadThrow m,
    MonadLogger m,
    MonadPostgres m,
    MonadOtel m,
    HasField "groupId" info Int,
    HasField "torrentId" info Int
  ) =>
  Map (Label "torrentHash" Text) info ->
  (Transaction m (Label "knownTorrentsStale" Bool, (Map (Label "torrentHash" Text) (Label "percentDone" Percentage))))
getAndUpdateTransmissionTorrentsStatus knownTorrents = inSpan' "getAndUpdateTransmissionTorrentsStatus" $ \span -> do
  let fields = ["hashString", "percentDone"]
  actualTorrents <-
    lift @Transaction $
      doTransmissionRequest'
        ( transmissionRequestListOnlyTorrents
            ( T2
                (label @"fields" fields)
                (label @"ids" (Map.keys knownTorrents))
            )
            $ do
              torrentHash <- Json.keyLabel @"torrentHash" "hashString" Json.asText
              percentDone <- Json.keyLabel @"percentDone" "percentDone" (Field.toJsonParser $ Field.jsonNumber >>> scientificPercentage)
              pure (torrentHash, percentDone)
        )
        <&> Map.fromList
  let toDelete = Map.difference knownTorrents actualTorrents
  if
    | Map.null toDelete -> do
        addEventSimple span "We know about all transmission hashes."
        pure (label @"knownTorrentsStale" False, actualTorrents)
    | otherwise -> inSpan' "Delete outdated transmission hashes" $ \span' -> do
        addAttribute
          span'
          "db.delete-transmission-hashes"
          ( toDelete
              & Map.toList
              & Enc.list
                ( \(k, v) ->
                    Enc.object
                      [ ("torrentHash", Enc.text k.torrentHash),
                        ("groupId", Enc.int v.groupId),
                        ("torrentId", Enc.int v.torrentId)
                      ]
                )
              & jsonAttribute
          )
        _ <-
          execute
            [fmt|
          UPDATE redacted.torrents_json
          SET transmission_torrent_hash = NULL,
              torrent_file = NULL
          WHERE transmission_torrent_hash = ANY (?::text[])
        |]
            $ Only (toDelete & Map.keys <&> (.torrentHash) & PGArray :: PGArray Text)
        pure (label @"knownTorrentsStale" True, actualTorrents)

getTransmissionTorrentsTable ::
  (MonadTransmission m, MonadThrow m, MonadLogger m, MonadOtel m) => m Html
getTransmissionTorrentsTable = do
  let fields =
        [ "hashString",
          "name",
          "percentDone",
          "percentComplete",
          "downloadDir",
          "files"
        ]
  doTransmissionRequest'
    ( transmissionRequestListAllTorrents fields $ do
        Json.asObject <&> KeyMap.toMapText
    )
    <&> \resp ->
      Html.toTable
        ( resp
            & List.sortOn (\m -> m & Map.lookup "percentDone" & fromMaybe (Json.Number 0))
            <&> Map.toList
            -- TODO
            & List.take 100
        )

data TransmissionRequest = TransmissionRequest
  { method :: Text,
    arguments :: Map Text Enc,
    tag :: Maybe Int
  }
  deriving stock (Show)

transmissionConnectionConfig :: T3 "host" Text "port" Int "usePlainHttp" Bool
transmissionConnectionConfig = (T3 (label @"host" "localhost") (label @"port" 9091) (label @"usePlainHttp" True))

transmissionRequestListAllTorrents :: (Monad m) => [Text] -> Json.ParseT e m out -> (TransmissionRequest, Json.ParseT e m [out])
transmissionRequestListAllTorrents fields parseTorrent =
  ( TransmissionRequest
      { method = "torrent-get",
        arguments =
          Map.fromList
            [ ("fields", Enc.list Enc.text fields)
            ],
        tag = Nothing
      },
    Json.key "torrents" $ Json.eachInArray parseTorrent
  )

transmissionRequestListOnlyTorrents ::
  ( HasField "ids" r1 [(Label "torrentHash" Text)],
    HasField "fields" r1 [Text],
    Monad m
  ) =>
  r1 ->
  Json.ParseT e m out ->
  (TransmissionRequest, Json.ParseT e m [out])
transmissionRequestListOnlyTorrents dat parseTorrent =
  ( TransmissionRequest
      { method = "torrent-get",
        arguments =
          Map.fromList
            [ ("ids", Enc.list (\i -> Enc.text i.torrentHash) dat.ids),
              ("fields", Enc.list Enc.text dat.fields)
            ],
        tag = Nothing
      },
    Json.key "torrents" $ Json.eachInArray parseTorrent
  )

transmissionRequestAddTorrent ::
  (HasField "torrentFile" r ByteString, Monad m) =>
  r ->
  ( TransmissionRequest,
    Json.ParseT err m (T2 "torrentHash" Text "torrentName" Text)
  )
transmissionRequestAddTorrent dat =
  ( TransmissionRequest
      { method = "torrent-add",
        arguments =
          Map.fromList
            [ ("metainfo", Enc.base64Bytes dat.torrentFile),
              ("paused", Enc.bool False)
            ],
        tag = Nothing
      },
    do
      let p method = Json.key method $ do
            hash <- Json.keyLabel @"torrentHash" "hashString" Json.asText
            name <- Json.keyLabel @"torrentName" "name" Json.asText
            pure $ T2 hash name
      p "torrent-duplicate" Json.<|> p "torrent-added"
  )

data TransmissionResponse output = TransmissionResponse
  { result :: TransmissionResponseStatus,
    arguments :: Maybe output,
    tag :: Maybe Int
  }
  deriving stock (Show)

data TransmissionResponseStatus
  = TransmissionResponseSuccess
  | TransmissionResponseFailure Text
  deriving stock (Show)

doTransmissionRequest' ::
  ( MonadTransmission m,
    MonadThrow m,
    MonadLogger m,
    MonadOtel m
  ) =>
  (TransmissionRequest, Json.Parse Error output) ->
  m output
doTransmissionRequest' req = inSpan' "Transmission Request" $ \span -> do
  resp <-
    doTransmissionRequest
      span
      transmissionConnectionConfig
      req
  case resp.result of
    TransmissionResponseFailure err -> appThrow span (AppExceptionTree $ nestedError "Transmission RPC error" $ singleError $ newError err)
    TransmissionResponseSuccess -> case resp.arguments of
      Nothing -> appThrow span "Transmission RPC error: No `arguments` field in response"
      Just out -> pure out

-- | Contact the transmission RPC, and do the CSRF protection dance.
--
-- Spec: https://github.com/transmission/transmission/blob/main/docs/rpc-spec.md
doTransmissionRequest ::
  ( MonadTransmission m,
    HasField "host" t1 Text,
    HasField "port" t1 Int,
    HasField "usePlainHttp" t1 Bool,
    MonadThrow m,
    MonadLogger m,
    MonadOtel m
  ) =>
  Otel.Span ->
  t1 ->
  (TransmissionRequest, Json.Parse Error output) ->
  m (TransmissionResponse output)
doTransmissionRequest span dat (req, parser) = do
  sessionId <- getCurrentTransmissionSessionId
  let textArg t = (Enc.text t, Otel.toAttribute @Text t)
  let encArg enc = (enc, enc & toOtelJsonAttr)
  let intArg i = (Enc.int i, Otel.toAttribute @Int i)

  let body :: [(Text, (Enc, Otel.Attribute))] =
        ( [ ("method", req.method & textArg),
            ("arguments", encArg $ Enc.map id req.arguments)
          ]
            <> (req.tag & foldMap (\t -> [("tag", t & intArg)]))
        )
  addAttributes
    span
    ( HashMap.fromList $
        body
          <&> bimap
            (\k -> [fmt|transmission.{k}|])
            (\(_, attr) -> attr)
    )
  resp <-
    Http.doRequestJson
      ( (Http.mkRequestOptions (T2 (label @"method" "POST") (label @"host" dat.host)))
          { Http.path = mkOptional ["transmission", "rpc"],
            Http.port = mkOptional dat.port,
            Http.headers = mkOptional $ (sessionId & ifExists ("X-Transmission-Session-Id",)),
            Http.usePlainHttp = mkOptional dat.usePlainHttp
          }
      )
      (body <&> second fst & Enc.object)
  -- Implement the CSRF protection thingy
  case resp & Http.getResponseStatus & (.statusCode) of
    409 -> inSpan' "New Transmission Session ID" $ \span' -> do
      tid <-
        resp
          & Http.getResponseHeader "X-Transmission-Session-Id"
          & nonEmpty
          & annotate [fmt|Missing "X-Transmission-Session-Id" header in 409 response: {showPretty resp}|]
          & unwrapIOError
          & liftIO
          <&> NonEmpty.head

      addAttribute span' "transmission.new_session_id" (tid, utf8LenientT)
      addAttribute span' "transmission.old_session_id" (sessionId, utf8LenientT >&< fromMaybe "<none yet>")

      updateTransmissionSessionId tid

      doTransmissionRequest span dat (req, parser)
    200 -> do
      addAttribute span "transmission.valid_session_id" (sessionId, utf8LenientT >&< fromMaybe "<none yet>")
      resp
        & Http.getResponseBody
        & Json.parseStrict
          ( Json.mapError singleError $ do
              result <-
                Json.key "result" Json.asText <&> \case
                  "success" -> TransmissionResponseSuccess
                  err -> TransmissionResponseFailure err
              arguments <-
                Json.keyMay "arguments" parser
              tag <-
                Json.keyMay
                  "tag"
                  (Field.toJsonParser (Field.jsonNumber >>> Field.boundedScientificIntegral "tag too long"))
              pure TransmissionResponse {..}
          )
        & first (Json.parseErrorTree "Cannot parse transmission RPC response")
        & \case
          Right a -> pure a
          Left err -> do
            case Json.eitherDecodeStrict' @Json.Value (resp & Http.getResponseBody) of
              Left _err -> pure ()
              Right val -> logInfo [fmt|failing transmission response: {showPrettyJson val}|]
            appThrow span (AppExceptionTree err)
    _ -> appThrow span $ AppExceptionPretty [[fmt|Non-200 response:|], pretty resp]

class MonadTransmission m where
  getCurrentTransmissionSessionId :: m (Maybe ByteString)
  updateTransmissionSessionId :: ByteString -> m ()

instance (MonadIO m) => MonadTransmission (AppT m) where
  getCurrentTransmissionSessionId = AppT (asks (.transmissionSessionId)) >>= readIORef
  updateTransmissionSessionId t = do
    var <- AppT $ asks (.transmissionSessionId)
    writeIORef var (Just t)
