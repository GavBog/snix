{-# LANGUAGE QuasiQuotes #-}

module Html where

import Builder
import Data.Aeson qualified as Json
import Data.Aeson.KeyMap qualified as KeyMap
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict qualified as Map
import IHP.HSX.QQ (hsx)
import PossehlAnalyticsPrelude
import Text.Blaze.Html (Html)
import Text.Blaze.Html5 qualified as Html
import Prelude hiding (span)

-- | Render an arbitrary json value to HTML in a more-or-less reasonable fashion.
mkVal :: Json.Value -> Html
mkVal = \case
  Json.Number n -> Html.lazyText $ buildTextLazy scientificDecimalT n
  Json.String s -> Html.toHtml @Text s
  Json.Bool True -> [hsx|<em>true</em>|]
  Json.Bool False -> [hsx|<em>false</em>|]
  Json.Null -> [hsx|<em>null</em>|]
  Json.Array arr -> toOrderedList mkVal arr
  Json.Object obj ->
    obj
      & KeyMap.toMapText
      & toDefinitionList (Html.toHtml @Text) mkVal

toOrderedList :: (Foldable t1) => (t2 -> Html) -> t1 t2 -> Html
toOrderedList mkValFn arr =
  arr
    & foldMap (\el -> Html.li $ mkValFn el)
    & Html.ol

toUnorderedList :: (Foldable t1) => (t2 -> Html) -> t1 t2 -> Html
toUnorderedList mkValFn arr =
  arr
    & foldMap (\el -> Html.li $ mkValFn el)
    & Html.ul

-- | Render a definition list from a Map
toDefinitionList :: (Text -> Html) -> (t -> Html) -> Map Text t -> Html
toDefinitionList mkKeyFn mkValFn obj =
  obj
    & Map.toList
    & foldMap (\(k, v) -> Html.dt (mkKeyFn k) <> Html.dd (mkValFn v))
    & Html.dl

-- | Render a table-like structure of json values as an HTML table.
toTable :: [[(Text, Json.Value)]] -> Html
toTable xs =
  case xs & nonEmpty of
    Nothing ->
      [hsx|<p>No results.</p>|]
    Just xs' -> do
      let headers = xs' & NonEmpty.head <&> fst <&> (\h -> [hsx|<th>{h}</th>|]) & mconcat
      let vals = xs' & foldMap (Html.tr . foldMap (Html.td . mkVal . snd))
      [hsx|
              <table class="table">
                <thead>
                  <tr>
                  {headers}
                  </tr>
                </thead>
                <tbody>
                  {vals}
                </tbody>
              </table>
          |]
