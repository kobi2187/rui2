## Layout Module - Public API
##
## Flutter-style two-pass layout system with composable helper functions.
##
## Usage:
##   import modules/layout/api
##
##   let stack = newHStack(spacing = 10.0, align = Center)
##   let area = contentArea(bounds, padding)
##   let (spacing, offset) = calculateDistributedSpacing(SpaceBetween, totalSpace, contentSize, 5, 8.0)
##
## Layout containers: HStack, VStack, Grid, FlexContainer, DockContainer, etc.
## Layout helpers: spacing distribution, alignment, padding application

import ./layout_core
import ./layout_calcs
import ./layout_containers
import ./layout_helpers

export layout_core
export layout_calcs
export layout_containers
export layout_helpers
