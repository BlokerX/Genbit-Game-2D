class_name GameLayers

# --- WARSTWY INTERFEJSU (CanvasLayer.layer) ---
const UI_TRANSITION : int = 110  # Czarny ekran ściemniania (musi przykryć absolutnie wszystko)
const UI_PAUSE : int      = 100   # Menu Pauzy (musi przykryć ekwipunek)
const UI_DIALOGUE_LOG : int = 70   # Historia dialogów (przykrywa okno rozmowy)
const UI_DIALOGUE : int     = 60   # Okno rozmowy z NPC (przykrywa ekwipunek)
const UI_HUD : int        = 50   # Twój główny ekran (Paski HP gracza, Minimapa, Ekwipunek)

# --- KONFIGURACJA WARSTW Z-INDEX ---
#const WORLD_UI : int   = 100   # Paski HP nad głowami, latające cyferki DMG
const HAZARD : int = 20
const ENTITIES : int   = 10    # Gracz, Wrogowie, Skrzynie, Drzwi
const LOOT : int       = 0     # Upuszczone przedmioty
const FLOOR_HAZARD : int     = -15   # Kwas, plamy, pułapki na ziemi
const FLOOR : int      = -20
#const BACKGROUND : int = -30
