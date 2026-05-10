-- Deprecated safety stub.
--
-- The old LegacyPlaceCleanup script was removed because it could delete active
-- Rojo-managed framework folders such as ServerScriptService.Server and
-- StarterPlayerScripts.Client. Keep this as a non-running ModuleScript so the
-- name remains documented without performing automatic cleanup.

return {
	Disabled = true,
	Reason = "Automatic broad cleanup is disabled. Rename confirmed unused objects to Deprecated_ manually instead.",
}
