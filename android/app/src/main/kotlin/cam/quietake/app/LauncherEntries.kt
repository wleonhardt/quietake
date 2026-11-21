package cam.quietake.app

/**
 * The two launcher entries (decision 029). Both are aliases of MainActivity, so
 * switching never disables the activity that the tiles and "Open with" start.
 */
object LauncherEntries {
    const val NORMAL = "cam.quietake.app.NormalAlias"
    const val NEUTRAL = "cam.quietake.app.NeutralAlias"

    /** The entry to enable first, then the entry to disable. */
    fun switchTo(neutral: Boolean): Pair<String, String> =
        if (neutral) NEUTRAL to NORMAL else NORMAL to NEUTRAL
}
