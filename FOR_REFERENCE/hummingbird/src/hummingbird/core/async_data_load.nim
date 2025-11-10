type LoadingState[T] = object
  data: Option[T]
  isLoading: bool
  error: Option[string]

defineWidget DataView[T]:
  props:
    loadData: proc(): Future[T]
    renderData: proc(data: T): Widget

  state:
    loading: LoadingState[T]

  render:
    try:
      # Initial load
      onMount = proc() {.async.} =
        widget.loading.isLoading = true
        try:
          let data = await widget.loadData()
          widget.loading.data = some(data)
        except:
          widget.loading.error = some(getCurrentExceptionMsg())
        finally:
          widget.loading.isLoading = false

      if widget.loading.isLoading:
        center:
          LoadingSpinner()
      elif widget.loading.error.isSome:
        ErrorView:
          message = widget.loading.error.get()
          onRetry = proc() =
            # Trigger remount
            widget.remount()
      else:
        widget.renderData(widget.loading.data.get())
    except:
      ErrorBoundary:
        error = getCurrentException()