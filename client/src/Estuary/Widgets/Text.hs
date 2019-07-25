{-# LANGUAGE ScopedTypeVariables, OverloadedStrings #-}

module Estuary.Widgets.Text where

import Reflex
import Reflex.Dom hiding (getKeyEvent,preventDefault)
import Reflex.Dom.Contrib.KeyEvent
import Control.Monad
import Control.Monad.Trans
import GHCJS.DOM.EventM
import Data.Maybe
import Data.Map (fromList)
import Data.Monoid
import Data.Text (Text)
import qualified Data.Text as T

import Estuary.Tidal.Types
import Estuary.WebDirt.Foreign
import Estuary.Reflex.Container
import Estuary.Widgets.GeneralPattern
import Estuary.Reflex.Utility
import Estuary.Widgets.Generic
import Estuary.Utility (lastOrNothing)
import Estuary.Types.Definition
import Estuary.Types.Hint
import Estuary.Types.TidalParser
import Estuary.Languages.TidalParsers
import Estuary.Types.Live
import Estuary.Types.TextNotation
import Estuary.Help.LanguageHelp
import Estuary.Reflex.Utility
import qualified Estuary.Types.Term as Term
import Estuary.Types.Language
import Estuary.Widgets.EstuaryWidget
import Estuary.Types.Context
import Estuary.Types.Variable

textWidget :: MonadWidget t m => Int -> Text -> Event t Text -> m (Dynamic t Text, Event t Text, Event t ())
textWidget rows i delta = do
  let attrs = constDyn $ ("class" =: "textInputToEndOfLine coding-textarea primary-color code-font" <> "rows" =: T.pack (show rows) <> "style" =: "height: auto")
  x <- textArea $ def & textAreaConfig_setValue .~ delta & textAreaConfig_attributes .~ attrs & textAreaConfig_initialValue .~ i
  let e = _textArea_element x
  e' <- wrapDomEvent (e) (onEventName Keypress) $ do
    y <- getKeyEvent
    if keyPressWasShiftEnter y then (preventDefault >> return True) else return False
  let evalEvent = fmap (const ()) $ ffilter (==True) e'
  let edits = _textArea_input x
  let value = _textArea_value x
  return (value,edits,evalEvent)
  where keyPressWasShiftEnter ke = (keShift ke == True) && (keKeyCode ke == 13)


textNotationParsers :: [TextNotation]
textNotationParsers = [Punctual,SuperContinent,SvgOp,CanvasOp,CineCer0] ++ (fmap TidalTextNotation tidalParsers)

textEditor :: MonadWidget t m => Int -> Dynamic t (Maybe Text) -> Dynamic t (Live (TextNotation,Text))
  -> EstuaryWidget t m (Variable t (Live (TextNotation, Text)))
textEditor nRows errorDyn updates = do
  ctx <- askContext
  (d,e,h) <- reflex $ do
    i <- sample $ current updates
    textNotationWidget ctx errorDyn nRows i (updated updates)
  hint h
  return $ Variable d e

textNotationWidget :: forall t m. MonadWidget t m => Dynamic t Context -> Dynamic t (Maybe Text) ->
  Int -> Live (TextNotation,Text) -> Event t (Live (TextNotation,Text)) ->
  m (Dynamic t (Live (TextNotation,Text)),Event t (Live (TextNotation,Text)),Event t Hint)
textNotationWidget ctx e rows i delta = divClass "textPatternChain" $ do -- *** TODO: change css class
  let deltaFuture = fmap forEditing delta
  let parserFuture = fmap fst deltaFuture
  let textFuture = fmap snd deltaFuture

  (d,evalButton,infoButton) <- divClass "fullWidthDiv" $ do
    let initialParser = fst $ forEditing i
    let parserMap = constDyn $ fromList $ fmap (\x -> (x,T.pack $ textNotationDropDownLabel x)) textNotationParsers
    d' <- dropdown initialParser parserMap $ ((def :: DropdownConfig t TidalParser) & attributes .~ constDyn ("class" =: "code-font primary-color primary-borders" <> "style" =: "background-color: transparent")) & dropdownConfig_setValue .~ parserFuture
    evalButton' <- divClass "textInputLabel" $ do
      x <- dynButton =<< translateDyn Term.Eval ctx
      e' <- holdUniqDyn e
      dynText =<< (return $ fmap (maybe "" (const "!")) e')
      return x
    infoButton' <- divClass "referenceButton" $ dynButton "?"
    return (d',evalButton',infoButton')

  (edit,eval) <- divClass "labelAndTextPattern" $ do
    let parserValue = _dropdown_value d -- Dynamic t TidalParser
    let parserEvent = _dropdown_change d
    let initialText = snd $ forEditing i
    textVisible <- toggle True infoButton
    helpVisible <- toggle False infoButton
    (textValue,textEvent,shiftEnter) <- hideableWidget textVisible "width-100-percent" $ textWidget rows initialText textFuture
    let languageToDisplayHelp = ( _dropdown_value d)
    hideableWidget helpVisible "width-100-percent" $ languageHelpWidget languageToDisplayHelp
    let v' = (,) <$> parserValue <*> textValue
    let editEvent = tagPromptlyDyn v' $ leftmost [() <$ parserEvent,() <$ textEvent]
    let evalEvent = tagPromptlyDyn v' $ leftmost [evalButton,shiftEnter]
    return (editEvent,evalEvent)
  let deltaPast = fmap forRendering delta
  pastValue <- holdDyn (forRendering i) $ leftmost [deltaPast,eval]
  futureValue <- holdDyn (forEditing i) $ leftmost [deltaFuture,edit]
  let value = f <$> pastValue <*> futureValue
  let deltaUpEdit = tagPromptlyDyn value edit
  let deltaUpEval = tagPromptlyDyn value eval
  let deltaUp = leftmost [deltaUpEdit,deltaUpEval]
  return (value,deltaUp,never)
  where
    f p x | p == x = Live p L3 -- *** TODO: this looks like it is a general pattern that should be with Live definitions
          | otherwise = Edited p x

{- labelWidget :: MonadWidget t m => Text -> Event t [Text] -> m (Event t Definition)
labelWidget i delta = divClass "textPatternChain" $ divClass "labelWidgetDiv" $ do
  let delta' = fmapMaybe lastOrNothing delta
  let attrs = constDyn $ ("class" =: "name-tag-textarea code-font primary-color")
  y <- textInput $ def & textInputConfig_setValue .~ delta' & textInputConfig_attributes .~ attrs & textInputConfig_initialValue .~ i
  return $ fmap LabelText $ _textInput_input y -}

-- the code below is an example of how the code just above might be rewritten
-- in the EstuaryWidget t m monad (see Estuary.Widgets.EstuaryWidget)
labelEditor :: MonadWidget t m => Dynamic t Text -> EstuaryWidget t m (Variable t Text)
labelEditor delta = do
  let attrs = constDyn $ ("class" =: "name-tag-textarea code-font primary-color")
  y <- reflex $ divClass "textPatternChain" $ divClass "labelWidgetDiv" $ do
    i <- (sample . current) delta
    textInput $ def & textInputConfig_setValue .~ (updated delta) & textInputConfig_attributes .~ attrs & textInputConfig_initialValue .~ i
  return $ Variable (_textInput_value y) (_textInput_input y)
