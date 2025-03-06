{-# LANGUAGE QuasiQuotes #-}

module Bencode where

import Aeson (jsonArray)
import Data.Aeson qualified as Json
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.BEncode (BEncode)
import Data.BEncode qualified as Bencode
import Data.ByteString.Lazy (LazyByteString)
import Data.ByteString.Lazy.Char8 qualified as Char8.Lazy
import Data.Char qualified as Char
import Data.List qualified as List
import Data.Map.Strict qualified as Map
import FieldParser qualified as Field
import Json (RestrictJsonOpts (RestrictJsonOpts), mkJsonArray)
import Json qualified
import MyPrelude
import Parse (Parse, fieldParser, mkParseNoContext, showContext)
import Pretty
import Text.Printf (printf)
import Prelude hiding (span)

bencodeBytes :: Parse BEncode ByteString
bencodeBytes = Parse.mkParseNoContext $ \(ctx, bencode) -> case bencode of
  Bencode.BString bs -> Right (toStrictBytes bs)
  _ -> Left $ [fmt|Expected a bencode byte-string, but got {bencode & prettyBencodeRestricted}, at {showContext ctx}|]

bencodeInteger :: Parse BEncode Integer
bencodeInteger = Parse.mkParseNoContext $ \(ctx, bencode) -> case bencode of
  Bencode.BInt i -> Right i
  _ -> Left $ [fmt|Expected a bencode integer, but got {bencode & prettyBencodeRestricted}, at {showContext ctx}|]

bencodeNatural :: Parse BEncode Natural
bencodeNatural = bencodeInteger >>> Parse.fieldParser Field.integralToNatural

bencodeDict :: Parse BEncode (Map Text BEncode)
bencodeDict = Parse.mkParseNoContext $ \(ctx, bencode) -> case bencode of
  Bencode.BDict d -> Right $ Map.mapKeys stringToText d
  _ -> Left $ [fmt|Expected a bencode dict, but got {bencode & prettyBencodeRestricted}, at {showContext ctx}|]

bencodeList :: Parse BEncode [BEncode]
bencodeList = Parse.mkParseNoContext $ \(ctx, bencode) -> case bencode of
  Bencode.BList l -> Right $ l
  _ -> Left $ [fmt|Expected a bencode list, but got {bencode & prettyBencodeRestricted}, at {showContext ctx}|]

parseBencode :: Parse ByteString BEncode
parseBencode = Parse.mkParseNoContext $ \(ctx, bs) -> do
  let lazy = toLazyBytes bs
  case Bencode.bRead lazy of
    Nothing -> Left $ [fmt|Failed to parse bencode: {Bencode.BString lazy & prettyBencodeRestricted}, at {showContext ctx}|]
    Just a -> Right a

bencodeTextLenient :: Parse BEncode Text
bencodeTextLenient = Parse.mkParseNoContext $ \(ctx, bencode) -> do
  case bencode of
    Bencode.BString bs -> Right (bs & toStrictBytes & bytesToTextUtf8Lenient)
    _ -> Left $ [fmt|Expected a bencode string, but got {bencode & prettyBencodeRestricted}, at {showContext ctx}|]

prettyBencodeRestricted :: BEncode -> Text
prettyBencodeRestricted =
  showPrettyJson . Json.restrictJson restriction . bencodeToJsonValue
  where
    restriction =
      RestrictJsonOpts
        { maxDepth = 3,
          maxSizeObject = 10,
          maxSizeArray = 10,
          maxStringLength = 100
        }

bencodeToJsonValue :: BEncode -> Json.Value
bencodeToJsonValue = \case
  Bencode.BString bs -> case bs & bytesToTextUtf8Lazy of
    -- If it’s not valid utf-8, let’s at least display a hexdump
    Left _ -> mkJsonArray $ "hexdump of bytes:" : (hexdump 0 bs <&> Json.String)
    Right a -> Json.String $ a & toStrict
  Bencode.BInt i -> Json.Number (fromIntegral @Integer @Scientific i)
  Bencode.BDict m -> Json.Object $ m & Map.toList <&> bimap Key.fromString bencodeToJsonValue & KeyMap.fromList
  Bencode.BList l -> jsonArray $ l <&> bencodeToJsonValue

-- | Unfold using f until the predicate becomes true.
unfoldUntil :: (b -> Bool) -> (b -> (a, b)) -> b -> [a]
unfoldUntil p f = List.unfoldr (\x -> guard (not (p x)) >> pure (f x))

-- | Return hex characters for the byte value.
bytehex :: Int -> String
bytehex n = printf "%02x" n

-- | Return a printable character, or a dot.
prChar :: Char -> Char
prChar ch
  | Char.ord ch >= 32 && Char.ord ch < 128 = ch
  | otherwise = '.'

-- | Return a string containing a pretty hexdump of xs using addresses
-- starting at n.
hexdump :: Int -> LazyByteString -> [Text]
hexdump n xs = zipWith hexLine addrs dlines
  where
    addrs = [n, n + 16 ..]
    dlines = unfoldUntil null (splitAt 16) (Char8.Lazy.unpack xs)
    hexLine :: Int -> String -> Text
    hexLine addr xs' = stringToText $ printf "%08x |%-23s  %-23s| %s" addr h1 h2 s
      where
        h1 = unwords $ map (bytehex . Char.ord) $ take 8 xs'
        h2 = unwords $ map (bytehex . Char.ord) $ drop 8 xs'
        s = map prChar xs'
