module Router where

import State(GlobalState(..),MenuRoute(..), windowSize, Settings (..), Prompt (..))
import Views.StartMenu
    ( renderStartMenu, handleInputStartMenu, handleUpdateStartMenu )
import Views.PauseMenu
    ( renderPauseMenu, handleInputPauseMenu, handleUpdatePauseMenu )
import Graphics.Gloss ( Picture (..), pictures, blank, rectangleSolid, makeColor )
import Graphics.Gloss.Interface.IO.Game
    ( Picture, Key(Char, SpecialKey), Event(EventMotion, EventKey, EventResize), SpecialKey (..), KeyState (..), Modifiers (..) )
import System.Exit (exitSuccess)
import Control.Exception (handle)
import Views.GameView (renderGameView, handleInputGameView, handleUpdateGameView, gridSizePx, gridSize)
import SDL.Audio (PlaybackState(Pause))
import Views.EditorView (renderEditorView, handleInputEditorView, handleUpdateEditorView)
import Prompt (renderPrompt, handleInputPrompt, handleUpdatePrompt)
import Data.Maybe
import Data.List (delete)

handleRender :: GlobalState -> IO Picture
handleRender s@(GlobalState { route = r, prompt = p }) = do
    renderedMain <- image
    renderedPrompt <- pImage
    return $ pictures [renderedMain, curtain, renderedPrompt]
    where
        image   | r == StartMenu = renderStartMenu s
                | r == GameView = renderGameView s
                | r == EditorView = renderEditorView s
                | r == PauseMenu = renderPauseMenu s
                | otherwise = error "Route not implemented"
        pImage  | isJust p = renderPrompt s (fromMaybe Prompt{} p)
                | otherwise = do return blank
        curtain | isJust p = 
                        if darkenBackground (fromMaybe Prompt{} p) 
                        then Color (makeColor 0 0 0 0.4) $ let (w,h) = windowSize $ settings s in rectangleSolid w h 
                        else blank
                | otherwise = blank

dummyEvent :: Event
dummyEvent = EventKey (SpecialKey KeyF25) Up (Modifiers {}) (0,0)

handleInput :: Event -> GlobalState -> IO GlobalState
handleInput (EventResize (w, h)) s = do return s { settings = set { windowSize = (fromIntegral w :: Float, fromIntegral h :: Float) } }
        where
          set = settings s
handleInput (EventMotion p) s = do return s { mousePos = p }
handleInput e@(EventKey k Down _ _) s = if cp then do
    let ps = promptState s
    ns <- newState ps
    return ns { keys = k : keys s }
    else do return s
        where
            cp = k `notElem` keys s
            r = route s
            (promptEvent,promptState) | isJust $ prompt s = (dummyEvent,handleInputPrompt e)
                                      | otherwise = (e, const s)
            newState | r == StartMenu = handleInputStartMenu promptEvent
                     | r == GameView = handleInputGameView promptEvent
                     | r == EditorView = handleInputEditorView promptEvent
                     | r == PauseMenu = handleInputPauseMenu promptEvent
                     | otherwise = error "Route not implemented"
handleInput e@(EventKey k Up _ _) s = do return s { keys = delete k $ keys s } -- maybe this could just return s

handleUpdate :: Float -> GlobalState -> IO GlobalState
handleUpdate f s@(GlobalState { route = r, prompt = p }) = do
    pState <- promptState
    newState pState
    where
        intState = s { clock = clock s + f }
        promptState | isJust p = handleUpdatePrompt f intState (fromMaybe Prompt{} p)
                    | otherwise = do return intState
        newState  | r == StartMenu = handleUpdateStartMenu f
                  | r == GameView = handleUpdateGameView f
                  | r == EditorView = handleUpdateEditorView f
                  | r == PauseMenu = handleUpdatePauseMenu f
                  | otherwise = error "Route not implemented"