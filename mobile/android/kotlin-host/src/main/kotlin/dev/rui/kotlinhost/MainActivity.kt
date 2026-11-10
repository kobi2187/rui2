package dev.rui.kotlinhost

import android.app.Activity
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import dev.rui.android.RuiActivity
import dev.rui.android.RuiScreens

/** An ordinary Android screen: one button per RUI mockup; a tap opens it in RUI. */
class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 48, 48, 48)
        }
        column.addView(TextView(this).apply {
            text = "Kotlin host: open an RUI screen"
            textSize = 20f
        })
        for (screen in RuiScreens.list(this)) {
            column.addView(Button(this).apply {
                text = screen
                tag = screen
                setOnClickListener { startActivity(RuiActivity.intent(this@MainActivity, screen)) }
            })
        }
        setContentView(ScrollView(this).apply { addView(column) })
    }
}
