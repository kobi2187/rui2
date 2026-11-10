package dev.rui.android;

import android.content.Context;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/** The screens the bundled RUI program offers, as listed in assets/rui_screens.txt by build_rui.sh. */
public final class RuiScreens {
    private RuiScreens() {}

    public static List<String> list(Context context) {
        List<String> names = new ArrayList<>();
        try (BufferedReader r = new BufferedReader(new InputStreamReader(
                context.getAssets().open("rui_screens.txt"), StandardCharsets.UTF_8))) {
            for (String line; (line = r.readLine()) != null; ) {
                if (!line.isBlank()) names.add(line.trim());
            }
        } catch (IOException e) {
            // No list packaged (build_rui.sh not run): offer nothing.
        }
        return names;
    }
}
