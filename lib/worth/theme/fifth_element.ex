defmodule Worth.Theme.FifthElement do
  @moduledoc """
  Fifth Element theme - Industrial retro-futuristic interface.

  Inspired by Jean-Paul Gaultier's 23rd-century New York from the 1997 film.
  Features: industrial orange chassis, terminal green text, glass viewport,
  elemental icons, warning strips, and CRT scanlines.
  """

  @behaviour Worth.Theme

  use Phoenix.Component

  def name, do: "fifth_element"
  def display_name, do: "Fifth Element"
  def description, do: "Industrial retro-futuristic - Moebius style sci-fi interface"

  def colors do
    %{
      background: "bg-[#0a0a0a]",
      surface: "bg-[#1a1a1a]",
      surface_elevated: "bg-[#2C2C2C]",
      border: "border-[#FF8C00]",
      text: "text-[#00FF41]",
      text_muted: "text-[#00CC33]",
      text_dim: "text-[#009922]",
      primary: "text-[#FF8C00]",
      secondary: "text-[#C0C0C0]",
      accent: "text-[#FDB813]",
      success: "text-[#00FF41]",
      error: "text-[#FF3333]",
      warning: "text-[#FDB813]",
      info: "text-[#FDB813]",
      # Button classes
      button_primary:
        "bg-[#FF3333] border-2 border-[#FF8C00] text-[#FF8C00] font-bold hover:bg-[#FF4444] shadow-[0_0_15px_#FF3333]/50",
      button_secondary: "bg-[#2C2C2C] border border-[#FF8C00]/50 text-[#C0C0C0] hover:border-[#FF8C00]",
      # Tab classes
      tab_active: "bg-[#FF8C00]/20 border-b-2 border-[#FF8C00] text-[#FF8C00]",
      tab_inactive: "text-[#666666] hover:text-[#00FF41]",
      # Status indicators
      status_running: "text-[#FDB813] animate-terminal-flicker",
      status_idle: "text-[#666666]",
      status_error: "text-[#FF3333]",
      # Message wrapper classes
      message_user_bg: "bg-[#FF8C00]/5",
      message_error_bg: "bg-[#FF3333]/10 border border-[#FF3333]/30",
      message_thinking_border: "border-l-2 border-[#FDB813]/30",
      message_system_bg: "bg-[#FDB813]/5 border border-[#FDB813]/20",
      # Input classes
      input_placeholder: "placeholder-[#009922]",
      input_disabled_bg: "bg-[#1a1a1a]",
      input_disabled_text: "text-[#666666]"
    }
  end

  def css do
    """
    /* Fifth Element Theme - Industrial Retro-Futuristic */

    /* Import fonts */
    @import url('https://fonts.googleapis.com/css2?family=Orbitron:wght@400;700;900&family=Fira+Code:wght@400;500&display=swap');

    /* Multi-Pass Chassis (card styling) */
    .multi-pass {
      position: relative;
      border: 2px solid #FF8C00;
      border-radius: 12px;
      background: linear-gradient(135deg, #1a1a1a 0%, #2C2C2C 100%);
      box-shadow: 
        0 0 0 1px #FF8C00 inset,
        0 4px 20px rgba(255, 140, 0, 0.2);
    }

    /* Screw details on corners */
    .multi-pass::before,
    .multi-pass::after {
      content: '';
      position: absolute;
      width: 8px;
      height: 8px;
      background: radial-gradient(circle, #FF8C00 30%, #666 100%);
      border-radius: 50%;
      box-shadow: 0 0 4px rgba(255, 140, 0, 0.5);
    }

    .multi-pass::before {
      top: 8px;
      left: 8px;
    }

    .multi-pass::after {
      top: 8px;
      right: 8px;
    }

    /* Glass Viewport */
    .glass-viewport {
      background: rgba(10, 10, 10, 0.85);
      backdrop-filter: blur(4px) brightness(0.8);
      border: 1px solid rgba(255, 140, 0, 0.3);
    }

    /* Warning Strip */
    .warning-strip {
      background: repeating-linear-gradient(
        -45deg,
        #FDB813,
        #FDB813 10px,
        #1a1a1a 10px,
        #1a1a1a 20px
      );
      height: 4px;
      width: 100%;
    }

    /* CRT Scanlines */
    .crt-overlay {
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
      z-index: 9999;
      background: repeating-linear-gradient(
        0deg,
        transparent,
        transparent 2px,
        rgba(0, 255, 65, 0.03) 2px,
        rgba(0, 255, 65, 0.03) 4px
      );
      animation: scanlines 0.1s linear infinite;
    }

    @keyframes scanlines {
      0% { transform: translateY(0); }
      100% { transform: translateY(4px); }
    }

    /* Terminal Flicker */
    @keyframes terminal-flicker {
      0%, 100% { opacity: 1; }
      92% { opacity: 1; }
      93% { opacity: 0.8; }
      94% { opacity: 1; }
      97% { opacity: 0.9; }
      98% { opacity: 1; }
    }

    .animate-terminal-flicker {
      animation: terminal-flicker 4s linear infinite;
    }

    /* Emergency Send Button */
    .emergency-button {
      background: linear-gradient(180deg, #FF4444 0%, #CC2222 100%);
      border: 3px solid #FF8C00;
      border-radius: 8px;
      color: #FF8C00;
      font-family: 'Orbitron', sans-serif;
      font-weight: 900;
      padding: 8px 24px;
      text-transform: uppercase;
      cursor: pointer;
      box-shadow: 
        0 0 10px rgba(255, 68, 68, 0.5),
        0 4px 0 #881111,
        inset 0 1px 0 rgba(255, 255, 255, 0.2);
      transition: all 0.1s ease;
    }

    .emergency-button:hover {
      background: linear-gradient(180deg, #FF5555 0%, #DD3333 100%);
      box-shadow: 
        0 0 20px rgba(255, 68, 68, 0.8),
        0 4px 0 #881111,
        inset 0 1px 0 rgba(255, 255, 255, 0.3);
      transform: translateY(-1px);
    }

    .emergency-button:active {
      transform: translateY(2px);
      box-shadow: 
        0 0 10px rgba(255, 68, 68, 0.5),
        0 1px 0 #881111,
        inset 0 2px 4px rgba(0, 0, 0, 0.3);
    }

    /* Elemental Icons Base */
    .elemental-icon {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 24px;
      height: 24px;
    }

    /* Terminal Text */
    .terminal-text {
      font-family: 'Fira Code', 'Courier New', monospace;
      color: #00FF41;
      text-shadow: 0 0 5px rgba(0, 255, 65, 0.5);
    }

    /* Body styling */
    body {
      font-family: 'Fira Code', monospace;
    }

    h1, h2, h3, h4, h5, h6 {
      font-family: 'Orbitron', sans-serif;
    }

    /* Scrollbar */
    ::-webkit-scrollbar {
      width: 8px;
      height: 8px;
    }

    ::-webkit-scrollbar-track {
      background: #0a0a0a;
    }

    ::-webkit-scrollbar-thumb {
      background: linear-gradient(180deg, #FF8C00 0%, #CC6600 100%);
      border-radius: 4px;
    }

    ::-webkit-scrollbar-thumb:hover {
      background: linear-gradient(180deg, #FFAA00 0%, #DD7700 100%);
    }

    /* Selection */
    ::selection {
      background: rgba(255, 140, 0, 0.3);
      color: #00FF41;
    }

    /* Input styling */
    input, textarea {
      font-family: 'Fira Code', monospace;
      background: #0a0a0a !important;
      border: 1px solid #FF8C00 !important;
      color: #00FF41 !important;
    }

    input:focus, textarea:focus {
      box-shadow: 0 0 10px rgba(255, 140, 0, 0.3) !important;
      outline: none !important;
    }

    input::placeholder, textarea::placeholder {
      color: #009922 !important;
    }
    """
  end

  # No custom templates - using color mapping + CSS
  def has_template?(_), do: false
  def render(_, _), do: {:error, :not_found}
end
