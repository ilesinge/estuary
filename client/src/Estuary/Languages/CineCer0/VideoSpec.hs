{-# LANGUAGE OverloadedStrings #-}

module Estuary.Languages.CineCer0.VideoSpec where

import Language.Haskell.Exts
import Control.Applicative
import Data.Time
import Data.Text
import TextShow

import Data.Tempo

import Estuary.Languages.CineCer0.Signal

--------- change String to Text throughout the pipeline!!!!!
data Colour = Colour (Signal String) | ColourRGB (Signal Rational) (Signal Rational) (Signal Rational) | ColourHSL (Signal Rational) (Signal Rational) (Signal Rational) | ColourRGBA (Signal Rational) (Signal Rational) (Signal Rational) (Signal Rational) | ColourHSLA (Signal Rational) (Signal Rational) (Signal Rational) (Signal Rational)

-- layer: right is video left is text!!!!!
data LayerSpec = LayerSpec {
  layer :: Either String String,  ----- both are synonims of Text
  z :: Signal Int,

  anchorTime :: (Tempo -> UTCTime -> UTCTime), -- vid reproduction
  playbackPosition :: Signal (Maybe NominalDiffTime),
  playbackRate :: Signal (Maybe Rational),
  shift :: Signal Rational,
  
  mute :: Signal Bool,  -- sound
  volume :: Signal Rational,

  fontFamily :: Signal String, -- text style
  fontSize :: Signal Rational,
  colour :: Colour,
  strike :: Signal Bool,
  bold :: Signal Bool,
  italic :: Signal Bool,
  border :: Signal Bool,

  posX :: Signal Rational,  -- geom
  posY :: Signal Rational,
  width :: Signal Rational,
  height :: Signal Rational,

  opacity :: Signal (Maybe Rational), -- video style
  blur :: Signal (Maybe Rational),
  brightness :: Signal (Maybe Rational),
  contrast :: Signal (Maybe Rational),
  grayscale :: Signal (Maybe Rational),
  saturate :: Signal (Maybe Rational),
  mask :: Signal Text
  }

instance Show LayerSpec where
  show s = show $ layer s

emptyLayerSpec :: LayerSpec
emptyLayerSpec = LayerSpec {
  layer = Right "",
  z = constantSignal 0,

  anchorTime = defaultAnchor,
  playbackPosition = playNatural_Pos,
  playbackRate = playNatural_Rate,
  shift = constantSignal 0,

  mute = constantSignal True,
  volume = constantSignal 0.0,

  fontFamily = constantSignal "sans-serif",
  fontSize = constantSignal 1,
  colour = Colour (constantSignal "White"),
  strike = constantSignal False,
  bold = constantSignal False,
  italic = constantSignal False,
  border = constantSignal False,

  posX = constantSignal 0.0,
  posY = constantSignal 0.0,
  width = constantSignal 1.0,
  height = constantSignal 1.0,
  opacity = constantSignal' Nothing,
  blur = constantSignal Nothing,
  brightness = constantSignal Nothing,
  contrast = constantSignal Nothing,
  grayscale = constantSignal Nothing,
  saturate = constantSignal Nothing,
  mask = emptyText
}

stringToLayerSpec :: String -> LayerSpec
stringToLayerSpec x = emptyLayerSpec { layer = Right x }

textToLayerSpec :: String -> LayerSpec
textToLayerSpec x = emptyLayerSpec { layer = Left x }

videoToLayerSpec :: String -> LayerSpec
videoToLayerSpec x = emptyLayerSpec { layer = Right x }

-- it should be just five arguments _ _ _ _ _
emptyText :: Signal Text
emptyText _ _ _ _ _ = Data.Text.empty

--
-- Style Functions --

setPosX :: Signal Rational -> LayerSpec -> LayerSpec
setPosX s v = v { posX = s }

shiftPosX :: Signal Rational -> LayerSpec -> LayerSpec
shiftPosX s v = v {
  posX = s * posX v
  }

setPosY :: Signal Rational -> LayerSpec -> LayerSpec
setPosY s v = v { posY = s }

shiftPosY :: Signal Rational -> LayerSpec -> LayerSpec
shiftPosY s v = v {
  posY = s * posY v
  }

setCoord :: Signal Rational -> Signal Rational -> LayerSpec -> LayerSpec
setCoord s1 s2 vs = vs { posX = s1, posY = s2}

shiftCoord :: Signal Rational -> Signal Rational -> LayerSpec -> LayerSpec
shiftCoord s1 s2 vs = vs {
  posX = s1 * posX vs,
  posY = s2 * posY vs
}

setWidth :: Signal Rational -> LayerSpec -> LayerSpec
setWidth s v = v { width = s }

shiftWidth :: Signal Rational -> LayerSpec -> LayerSpec
shiftWidth s v = v {
  width = s * width v
  }

setHeight :: Signal Rational -> LayerSpec -> LayerSpec
setHeight s v = v { height = s }

shiftHeight :: Signal Rational -> LayerSpec -> LayerSpec
shiftHeight s v = v {
  height = s * height v
  }

setSize :: Signal Rational -> LayerSpec -> LayerSpec
setSize s vs = vs { width = s, height = s}

shiftSize :: Signal Rational -> LayerSpec -> LayerSpec
shiftSize s vs = vs {
  width = s * width vs,
  height = s * height vs
}

setZIndex :: Signal Int -> LayerSpec -> LayerSpec
setZIndex n tx = tx { z = n }

setFontFamily :: Signal String -> LayerSpec -> LayerSpec
setFontFamily s tx = tx { fontFamily = s }

-- maybe not
setFontSize :: Signal Rational -> LayerSpec -> LayerSpec
setFontSize s tx = tx { fontSize = s }

setStrike :: LayerSpec -> LayerSpec
setStrike tx = tx { strike = constantSignal True }

setBold :: LayerSpec -> LayerSpec
setBold tx = tx { bold = constantSignal True}

setItalic :: LayerSpec -> LayerSpec
setItalic tx = tx { italic = constantSignal True}

setBorder :: LayerSpec -> LayerSpec
setBorder tx = tx { border = constantSignal True}

setColourStr :: Signal String -> LayerSpec -> LayerSpec
setColourStr clr tx = tx { colour = Colour clr }

setRGB :: Signal Rational -> Signal Rational -> Signal Rational -> LayerSpec -> LayerSpec
setRGB r g b tx = tx { colour = ColourRGB r g b}

setHSL :: Signal Rational -> Signal Rational -> Signal Rational -> LayerSpec -> LayerSpec
setHSL h s v tx = tx { colour = ColourHSL h s v}

setRGBA :: Signal Rational -> Signal Rational -> Signal Rational -> Signal Rational -> LayerSpec -> LayerSpec
setRGBA r g b a tx = tx { colour = ColourRGBA r g b a}

setHSLA :: Signal Rational -> Signal Rational -> Signal Rational -> Signal Rational -> LayerSpec -> LayerSpec
setHSLA h s l a tx = tx { colour = ColourHSLA h s l a}

-- Filters

setOpacity :: Signal (Maybe Rational) -> LayerSpec -> LayerSpec
setOpacity s v = v { opacity = s }

shiftOpacity :: Signal (Maybe Rational) -> LayerSpec -> LayerSpec
shiftOpacity s v = v {
  opacity = multipleMaybeSignal s (opacity v)
  }

setBlur :: Signal (Maybe Rational) -> LayerSpec -> LayerSpec
setBlur s v = v { blur = s }

shiftBlur :: Signal (Maybe Rational) -> LayerSpec -> LayerSpec
shiftBlur s v = v {
  blur = multipleMaybeSignal s (blur v)
  }

setBrightness :: Signal (Maybe Rational) -> LayerSpec -> LayerSpec
setBrightness s v = v { brightness = s }

shiftBrightness :: Signal (Maybe Rational) -> LayerSpec -> LayerSpec
shiftBrightness s v = v {
  brightness = multipleMaybeSignal s (brightness v)
  }

setContrast :: Signal (Maybe Rational) -> LayerSpec -> LayerSpec
setContrast s v = v { contrast = s }

shiftContrast :: Signal (Maybe Rational) -> LayerSpec -> LayerSpec
shiftContrast s v = v {
  contrast = multipleMaybeSignal s (contrast v)
  }

setGrayscale :: Signal (Maybe Rational) -> LayerSpec -> LayerSpec
setGrayscale s v = v { grayscale = s }

shiftGrayscale :: Signal (Maybe Rational) -> LayerSpec -> LayerSpec
shiftGrayscale s v = v {
  grayscale = multipleMaybeSignal s (grayscale v)
  }

setSaturate :: Signal (Maybe Rational) -> LayerSpec -> LayerSpec
setSaturate s v = v { saturate = s }

shiftSaturate :: Signal (Maybe Rational) -> LayerSpec -> LayerSpec
shiftSaturate s v = v {
  saturate = multipleMaybeSignal s (saturate v)
  }


-- Masks

circleMask :: Signal Rational -> LayerSpec -> LayerSpec
circleMask s vs = vs {
  mask = \a b c d e -> "clip-path:circle(" <> (showt (realToFrac ((
  (((s a b c d e)*71)-71)*(-1)
  ) :: Rational) :: Double)) <> "% at 50% 50%);"
  }

circleMask' :: Signal Rational -> Signal Rational -> Signal Rational -> LayerSpec -> LayerSpec
circleMask' m n s vs = vs {
  mask = \a b c d e -> "clip-path:circle(" <> (showt (realToFrac ((
  (((m a b c d e)*71)-71)*(-1)
  ) :: Rational) :: Double)) <> "% at " <> (showt (realToFrac (((n a b c d e)*100) :: Rational) :: Double)) <> "% " <> (showt (realToFrac (((s a b c d e)*100) :: Rational) :: Double)) <> "%);"
  }

sqrMask :: Signal Rational -> LayerSpec -> LayerSpec
sqrMask s vs = vs {
  mask = \a b c d e -> "clip-path: inset(" <> (showt (realToFrac (((s a b c d e)*50) :: Rational) :: Double)) <> "%);"
  }

rectMask :: Signal Rational -> Signal Rational -> Signal Rational -> Signal Rational -> LayerSpec -> LayerSpec
rectMask m n s t vs = vs {
  mask = \ a b c d e -> "clip-path: inset(" <> (showt (realToFrac (((m a b c d e)*100) :: Rational) :: Double)) <> "% " <> (showt (realToFrac (((n a b c d e)*100) :: Rational) :: Double)) <> "% " <> (showt (realToFrac (((s a b c d e)*100) :: Rational) :: Double)) <> "% " <> (showt (realToFrac (((t a b c d e)*100) :: Rational) :: Double)) <> "%);"
  }

-- audio --  keep it simple just mute, unmute and volume

setMute :: LayerSpec -> LayerSpec
setMute v = v { mute = constantSignal True }

setUnmute :: LayerSpec -> LayerSpec
setUnmute v = v { mute = constantSignal False}

setVolume:: Signal Rational -> LayerSpec -> LayerSpec
setVolume vol v = v { volume = vol }

-- position 

setShift:: Rational -> LayerSpec -> LayerSpec
setShift sh vs = vs { shift = constantSignal sh}


-- Time Functions --

-- anchorTime:: -- parser
quant:: Rational -> Rational -> LayerSpec -> LayerSpec
quant nc offset vs = vs { anchorTime = quantAnchor nc offset }

freerun :: LayerSpec -> LayerSpec
freerun vs = vs {
  playbackPosition = freeRun
}

playNatural :: LayerSpec -> LayerSpec
playNatural vs = vs {
  playbackPosition = playNatural_Pos,
  playbackRate = playNatural_Rate
}

playSnap :: LayerSpec -> LayerSpec
playSnap vs = vs {
  playbackPosition = playRound_Pos,
  playbackRate = playRound_Rate
  }

playSnapMetre :: LayerSpec -> LayerSpec
playSnapMetre vs = vs {
  playbackPosition = playRoundMetre_Pos,
  playbackRate = playRoundMetre_Rate
  }

playEvery :: Rational -> LayerSpec -> LayerSpec
playEvery m vs = vs {
  playbackPosition = playEvery_Pos m,
  playbackRate = playEvery_Rate m
  }

playChop :: Rational -> Rational -> Rational -> LayerSpec -> LayerSpec
playChop k l m vs = vs {
  playbackPosition = playChop_Pos k l m,
  playbackRate = playChop_Rate k l m
}

playRate :: Rational -> LayerSpec -> LayerSpec
playRate m vs = vs {
  playbackPosition = rate_Pos m,
  playbackRate = rate_Rate m
}