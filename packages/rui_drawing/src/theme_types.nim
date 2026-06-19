## Theme Types - Shared Type Definitions
##
## This module contains type definitions shared between theme_sys_core
## and drawing_effects to avoid circular dependencies.

type
  ThemeState* = enum
    Normal     # Default state
    Disabled
    Hovered
    Pressed    # Being clicked/touched
    Focused    # Keyboard focus
    Selected   # For lists, tabs etc
    DragOver   # When dragging something over this widget

  ThemeIntent* = enum
    Default    # Normal appearance
    Info       # Informational elements
    Success    # Positive actions/states
    Warning    # Caution required
    Danger     # Destructive or error states

  # Visual effect styles
  BevelStyle* = enum
    Flat       # No bevel (default flat design)
    Raised     # Classic 3D raised button (BeOS, Windows 98)
    Sunken     # Classic 3D pressed/inset
    Ridge      # Windows 98 panel ridge effect
    Groove     # Windows 98 panel groove effect
    Soft       # Soft bevel (modern, subtle)
    Convex     # macOS Aqua convex button effect
    Drop       # Dropped 3D effect
    Interior   # Interior shadow effect (inset content)
    Flatsoft   # Flat design with soft highlight
    Flatconvex # Flat design with convex highlight

  GradientDirection* = enum
    Vertical
    Horizontal
    Radial
