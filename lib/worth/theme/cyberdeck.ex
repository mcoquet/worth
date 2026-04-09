defmodule Worth.Theme.Cyberdeck do
  @moduledoc """
  Cyberdeck theme - inspired by Ops Center's tactical HUD aesthetic.

  Dark void background with neon cyan/amber/magenta accents, cyber-grid backgrounds,
  CRT scanlines, corner-bracket cards, and monospace typography.
  """

  @behaviour Worth.Theme

  use Phoenix.Component

  def name, do: "cyberdeck"
  def display_name, do: "Cyberdeck"
  def description, do: "Tactical HUD aesthetic - neon cyber command interface"

  def colors do
    %{
      background: "bg-[#0c0c12]",
      surface: "bg-[#16161e]",
      surface_elevated: "bg-[#1e1e28]",
      border: "border-[#00d4ff]/20",
      text: "text-[#d4d4d4]",
      text_muted: "text-[#8888a0]",
      text_dim: "text-[#555566]",
      primary: "text-[#00d4ff]",
      secondary: "text-[#f0c040]",
      accent: "text-[#ff40a0]",
      success: "text-[#40ff80]",
      error: "text-[#ff4040]",
      warning: "text-[#f0c040]",
      info: "text-[#40a0ff]",
      # Button classes
      button_primary:
        "bg-[#00d4ff]/20 border border-[#00d4ff]/40 text-[#00d4ff] hover:bg-[#00d4ff]/30 hover:shadow-[0_0_15px_#00d4ff]/30",
      button_secondary:
        "bg-[#1e1e28] border border-[#00d4ff]/20 text-[#8888a0] hover:bg-[#00d4ff]/10 hover:border-[#00d4ff]/40",
      # Tab classes
      tab_active: "border-b-2 border-[#00d4ff] text-[#00d4ff]",
      tab_inactive: "text-[#555566] hover:text-[#8888a0]",
      # Status indicators
      status_running: "text-[#f0c040] animate-cyber-pulse",
      status_idle: "text-[#555566]",
      status_error: "text-[#ff4040]"
    }
  end

  def css do
    """
    /* Cyberdeck Theme - Tactical Ops Interface */

    /* Cyber Grid Background */
    .cyber-grid-bg {
      background-image:
        linear-gradient(rgba(0, 212, 255, 0.03) 1px, transparent 1px),
        linear-gradient(90deg, rgba(0, 212, 255, 0.03) 1px, transparent 1px);
      background-size: 24px 24px;
    }

    /* CRT Scanline Overlay */
    .scanline-overlay {
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
        rgba(0, 0, 0, 0.08) 2px,
        rgba(0, 0, 0, 0.08) 4px
      );
      mix-blend-mode: multiply;
    }

    /* Cyber Card with Corner Brackets */
    .cyber-card {
      position: relative;
      border: 1px solid rgba(0, 212, 255, 0.25);
      background: rgba(22, 22, 30, 0.95);
    }

    .cyber-card::before,
    .cyber-card::after {
      content: '';
      position: absolute;
      width: 12px;
      height: 12px;
      border-color: rgba(0, 212, 255, 0.6);
      border-style: solid;
    }

    .cyber-card::before {
      top: -1px;
      left: -1px;
      border-width: 2px 0 0 2px;
    }

    .cyber-card::after {
      bottom: -1px;
      right: -1px;
      border-width: 0 2px 2px 0;
    }

    /* Neon Glows */
    .glow-cyan {
      text-shadow: 0 0 7px rgba(0, 212, 255, 0.8), 0 0 15px rgba(0, 212, 255, 0.4);
    }

    .glow-amber {
      text-shadow: 0 0 7px rgba(240, 192, 64, 0.8), 0 0 15px rgba(240, 192, 64, 0.4);
    }

    .box-glow-cyan {
      box-shadow: 0 0 8px rgba(0, 212, 255, 0.3), inset 0 0 8px rgba(0, 212, 255, 0.05);
    }

    /* HUD Divider */
    .hud-divider {
      border: none;
      height: 1px;
      background: linear-gradient(
        90deg,
        rgba(0, 212, 255, 0.5) 0%,
        rgba(0, 212, 255, 0.1) 50%,
        transparent 100%
      );
    }

    /* Status Dot Animation */
    @keyframes cyber-pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.6; }
    }

    .animate-cyber-pulse {
      animation: cyber-pulse 2s ease-in-out infinite;
    }

    /* Cyber Status Dot */
    .cyber-status-dot {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      display: inline-block;
      animation: cyber-pulse 2s ease-in-out infinite;
    }

    .cyber-status-dot.online {
      background: #40ff80;
      box-shadow: 0 0 6px rgba(64, 255, 128, 0.5);
    }

    .cyber-status-dot.warning {
      background: #f0c040;
      box-shadow: 0 0 6px rgba(240, 192, 64, 0.5);
    }

    .cyber-status-dot.critical {
      background: #ff4040;
      box-shadow: 0 0 6px rgba(255, 64, 64, 0.5);
    }

    /* Selection */
    ::selection {
      background: rgba(0, 212, 255, 0.3);
      color: #f0f0f0;
    }

    /* Scrollbar */
    ::-webkit-scrollbar {
      width: 6px;
      height: 6px;
    }

    ::-webkit-scrollbar-track {
      background: #0c0c12;
    }

    ::-webkit-scrollbar-thumb {
      background: rgba(0, 212, 255, 0.3);
      border-radius: 1px;
    }

    ::-webkit-scrollbar-thumb:hover {
      background: rgba(0, 212, 255, 0.5);
    }
    """
  end

  # No custom templates - using color mapping + CSS
  def has_template?(_), do: false
  def render(_, _), do: {:error, :not_found}
end
