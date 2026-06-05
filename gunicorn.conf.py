import os
import threading

bind = f"0.0.0.0:{os.environ.get('DATABRICKS_APP_PORT', '8000')}"
workers = 1          # PTY fds + sessions dict are process-local
threads = 16         # Concurrent request handling (poll + input + resize + websocket)
worker_class = "gthread"
timeout = 60         # WebSocket connections are long-lived; balance between WS and hung-worker detection
graceful_timeout = 10  # Databricks gives 15s after SIGTERM
accesslog = "-"
errorlog = "-"
loglevel = "info"


def post_worker_init(worker):
    """Initialize app - resolve owner immediately, run full setup in background."""
    import logging
    import app as app_module
    from app import get_token_owner, initialize_app
    import app_state

    logger = logging.getLogger(__name__)

    # CRITICAL: Resolve app owner BEFORE serving requests (security requirement)
    try:
        owner = get_token_owner()
        if owner:
            app_module.app_owner = owner
            logger.info(f"App owner resolved: {owner}")
            app_state.set_app_owner(owner)
        else:
            logger.warning("Could not determine app owner - authorization may fail")
    except Exception as e:
        logger.error(f"Failed to resolve app owner: {e}", exc_info=True)

    # Run full initialization in background thread (git setup, CLI installs, etc.)
    def run_init():
        try:
            initialize_app()
        except Exception as e:
            logger.error(f"Background initialization failed: {e}", exc_info=True)

    init_thread = threading.Thread(target=run_init, daemon=True, name="app-init")
    init_thread.start()
