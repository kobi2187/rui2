package dev.rui.android;

import android.app.NativeActivity;
import android.content.Context;
import android.content.Intent;

/**
 * Shows an RUI program: a {@link NativeActivity} whose native side is
 * libmain.so (raylib's android_native_app_glue calls the program's main).
 *
 * <p>Start it from any app with {@link #intent}; the String extras reach the
 * RUI side through {@code intentExtra(key)} (packages/rui/src/android_host.nim).
 */
public class RuiActivity extends NativeActivity {
    /** Which screen of the program to show; the program decides what names mean. */
    public static final String EXTRA_SCREEN = "screen";
    /** An RUI theme name ("material", "daylight", ...). */
    public static final String EXTRA_THEME = "theme";

    /** An Intent that opens {@code screen} in RUI, in the program's default theme. */
    public static Intent intent(Context context, String screen) {
        return intent(context, screen, null);
    }

    /** An Intent that opens {@code screen} in RUI with {@code theme} (null: the default). */
    public static Intent intent(Context context, String screen, String theme) {
        Intent i = new Intent(context, RuiActivity.class);
        i.putExtra(EXTRA_SCREEN, screen);
        if (theme != null) i.putExtra(EXTRA_THEME, theme);
        return i;
    }
}
