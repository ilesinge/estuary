{-# LANGUAGE OverloadedStrings #-}

module Estuary.Reflex.Utility where

import Reflex
import Reflex.Dom
import Control.Monad (liftM)
import Data.Map
import Data.Text as T
import GHCJS.DOM.EventM
import qualified GHCJS.DOM.Types as G
import Data.Map
import Data.Maybe
import Data.Monoid
import Control.Monad
import GHCJS.DOM.HTMLSelectElement as Select
import Control.Monad hiding (forM_) -- for 'guard'
import Safe -- for readMay
-- import GHCJS.DOM.Element hiding (error) --for 'change'
import GHCJS.DOM.GlobalEventHandlers (change)
import Data.List (nub, elemIndex)

import Estuary.Types.Term
import Estuary.Types.Context
import Estuary.Types.Language

mapDyn' :: MonadWidget t m => (a -> b) -> m (Dynamic t a) -> m (Dynamic t b)
mapDyn' f a = do
  let f' = constDyn f
  a' <- a
  combineDyn ($) f' a'

apDyn :: MonadWidget t m => m (Dynamic t (a -> b)) -> m (Dynamic t a) -> m (Dynamic t b)
apDyn f a = do
  f' <- f
  a' <- a
  combineDyn ($) f' a'

translateDyn :: MonadWidget t m => Term -> Dynamic t Context -> m (Dynamic t Text)
translateDyn t = mapDyn (translate t . language)

translationList :: MonadWidget t m => Dynamic t Context -> [(Language,a)] -> m (Dynamic t a)
translationList c m = do
  let m' = fromList m
  let d = snd (m!!0)
  l <- mapDyn language c
  mapDyn (\k -> findWithDefault d k m') l

--Button with dynamic label. A final version that uses >=> from Control.Monad to compose together two a -> m b functions
dynButton :: MonadWidget t m => Dynamic t Text -> m (Event t ())
dynButton = (mapDyn button) >=> dynE

dynButtonWithChild :: MonadWidget t m => String -> m () -> m (Event t ())
dynButtonWithChild cls child = do
  (e, _) <- elAttr' "div" (fromList [("type", "button"), ("class", T.pack $ cls ++ " btn")]) child
  return $ domEvent Click e

-- | dynE is like dyn from Reflex, specialized for widgets that return
-- events. A dynamic argument updates the widget, and the return value is
-- already flattened to just being the events returned by the child widget.
dynE :: MonadWidget t m => Dynamic t (m (Event t a)) -> m (Event t a)
dynE x = dyn x >>= switchPromptly never

-- Anytime an event is received issue another event of a given constant value.
constEvent :: Reflex t => a -> Event t b -> Event t a
constEvent a b = fmap (const a) b

-- Whenever a received event matches a value, issue another event of a given
-- constant value.
matchEvent :: (Reflex t, Eq a) => a -> b -> Event t a -> Event t b
matchEvent a b = fmap (const  b) . ffilter (==a)

-- a button that, instead of producing Event t (), produces an event of
-- some constant value
button' :: (MonadWidget t m) => Text -> a -> m (Event t a)
button' t r = do
  x <- button t
  return $ fmap (const r) x

-- Button With Dynamic attributes
buttonDynAttrs :: MonadWidget t m => Text -> a -> Dynamic t (Map Text Text)-> m (Event t a)
buttonDynAttrs s val attrs = do
  (e, _) <- elDynAttr' "button" attrs $ text s
  let event = domEvent Click e
  return $ fmap (const val) event

-- Creates dropdown Menu with Subheaders
-- takes a Map of integers (the order everything should be displayed in)
-- to String tuples. The first String of the tuple indicates a subheader,
-- and the second indicates the selectable item under it. DropdownConfig options
-- expect the same as with a regular dropdown
dropdownOpts :: (MonadWidget t m) => Int -> Map Int (Text,Text) ->  DropdownConfig t Int -> m (Dropdown t Int)
dropdownOpts k0 setUpMap (DropdownConfig setK attrs) = do
  let options = fromList $ Prelude.zip (keys setUpMap) $ fmap snd $ elems setUpMap
  let optGroups = fromList $ Prelude.zip (keys setUpMap) $ fmap fst $ elems setUpMap
  let optGroupPositions = fmap (\x-> maybe (0) id $ Data.List.elemIndex x (elems optGroups)) $ nub $ elems optGroups -- [Int]
  (eRaw, _) <- elDynAttr' "select" attrs $ do
    let optionsWithDefault = constDyn $ if Data.Map.lookup k0 options == Nothing then Data.Map.union (k0 =: "") options else options
    listWithKey optionsWithDefault $ \k v -> do
      if not (elem k optGroupPositions) then blank else do
        elAttr "optgroup" ("label"=:(maybe "" id $ Data.Map.lookup k optGroups)) $ blank
      elAttr "option" ("value" =: (T.pack . show) k <> if k == k0 then "selected" =: "selected" else mempty) $ dynText v
  let e = G.uncheckedCastTo HTMLSelectElement $ _el_element eRaw
  performEvent_ $ fmap (Select.setValue e . show) setK
  eChange <- wrapDomEvent e (`on` change) $ do
--    kStr <- fromMaybe "" <$> Select.getValue e
    kStr <- Select.getValue e
    return $ readMay kStr
  let readKey mk = fromMaybe k0 $ do
        k <- mk
        guard $ Data.Map.member k options
        return k
  dValue <- mapDyn readKey =<< holdDyn (Just k0) (leftmost [eChange, fmap Just setK])
  return $ Dropdown dValue (fmap readKey eChange) -- @clean this.
