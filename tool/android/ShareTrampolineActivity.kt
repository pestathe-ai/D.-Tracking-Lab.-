package dev.dtrackinglab.d_tracking_lab

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle

/**
 * Riceve "Condividi" e la voce del menu di selezione testo
 * ("Aggiungi a D. Tracking lab"), ricorda da quale app arriva
 * e passa tutto alla schermata principale.
 */
class ShareTrampolineActivity : Activity() {
    companion object {
        const val ACTION_ADD = "dev.dtrackinglab.ADD"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val i = intent
        val text = when (i?.action) {
            Intent.ACTION_PROCESS_TEXT ->
                i.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
            Intent.ACTION_SEND -> listOfNotNull(
                i.getStringExtra(Intent.EXTRA_SUBJECT),
                i.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
            ).joinToString("\n")
            else -> null
        } ?: ""
        var source: String? = callingPackage
        if (source == null && Build.VERSION.SDK_INT >= 22) {
            source = referrer?.host
        }
        val forward = Intent(this, MainActivity::class.java).apply {
            action = ACTION_ADD
            putExtra("text", text)
            putExtra("source", source ?: "")
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
        }
        startActivity(forward)
        finish()
    }
}
