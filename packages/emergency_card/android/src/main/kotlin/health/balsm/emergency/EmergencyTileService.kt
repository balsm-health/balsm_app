package health.balsm.emergency

import android.content.Context
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import org.json.JSONObject

// Balsm Emergency quick-settings tile (T128).
//
// Reads a minimal, non-sensitive projection of the patient's emergency card
// from SharedPreferences ("balsm_emergency", key "data") written by the Flutter
// host app, and surfaces the blood type on the tile label. Tapping the tile is
// expected to deep-link into the in-app emergency card (wired by the host).
//
// No PHI is fetched over the network here — passive read of local data only.
class EmergencyTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }

    override fun onClick() {
        super.onClick()
        // Host app handles the deep link to /emergency/card.
        updateTile()
    }

    private fun updateTile() {
        val tile = qsTile ?: return
        val data = loadEmergencyData()
        val bloodType = data?.optString("bloodType")?.takeIf { it.isNotBlank() }

        tile.label = "Emergency"
        tile.subtitle = bloodType ?: "Tap to open"
        tile.state = if (data != null) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.updateTile()
    }

    private fun loadEmergencyData(): JSONObject? {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(PREFS_KEY, null) ?: return null
        return try {
            JSONObject(raw)
        } catch (_: Exception) {
            null
        }
    }

    private companion object {
        const val PREFS_NAME = "balsm_emergency"
        const val PREFS_KEY = "data"
    }
}
