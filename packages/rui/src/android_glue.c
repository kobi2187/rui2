/* What an RUI app on Android asks of its Activity through JNI: the extras of
 * the Intent that started it, and the display density. raylib owns the
 * NativeActivity (android_native_app_glue) and hands it out as GetAndroidApp. */
#include <jni.h>
#include <string.h>
#include <android/configuration.h>
#include <android_native_app_glue.h>

struct android_app *GetAndroidApp(void);

/* Copies the String extra `key` of the starting Intent into buf (NUL-ended).
 * Returns its length, or -1 when there is no such extra. */
int rui_intent_extra(const char *key, char *buf, int bufLen) {
  struct android_app *app = GetAndroidApp();
  if (!app || !app->activity || bufLen <= 0) return -1;
  JavaVM *vm = app->activity->vm;
  JNIEnv *env = NULL;
  if ((*vm)->AttachCurrentThread(vm, &env, NULL) != JNI_OK) return -1;
  int result = -1;
  jobject activity = app->activity->clazz;
  jclass activityClass = (*env)->GetObjectClass(env, activity);
  jmethodID getIntent = (*env)->GetMethodID(env, activityClass, "getIntent",
                                            "()Landroid/content/Intent;");
  jobject intent = (*env)->CallObjectMethod(env, activity, getIntent);
  if (intent) {
    jclass intentClass = (*env)->GetObjectClass(env, intent);
    jmethodID getExtra = (*env)->GetMethodID(env, intentClass, "getStringExtra",
                                             "(Ljava/lang/String;)Ljava/lang/String;");
    jstring jkey = (*env)->NewStringUTF(env, key);
    jstring value = (jstring)(*env)->CallObjectMethod(env, intent, getExtra, jkey);
    if (value) {
      const char *utf = (*env)->GetStringUTFChars(env, value, NULL);
      int n = (int)strlen(utf);
      if (n >= bufLen) n = bufLen - 1;
      memcpy(buf, utf, n);
      buf[n] = 0;
      result = n;
      (*env)->ReleaseStringUTFChars(env, value, utf);
    }
  }
  if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
  (*vm)->DetachCurrentThread(vm);
  return result;
}

/* Dots per inch of the display (160 is Android's 1x, "mdpi"). */
int rui_display_dpi(void) {
  struct android_app *app = GetAndroidApp();
  if (!app || !app->config) return 160;
  int d = AConfiguration_getDensity(app->config);
  return d > 0 ? d : 160;
}

/* Whether the system is in night (dark) mode. */
int rui_night_mode(void) {
  struct android_app *app = GetAndroidApp();
  if (!app || !app->config) return 0;
  return AConfiguration_getUiModeNight(app->config) == ACONFIGURATION_UI_MODE_NIGHT_YES;
}

/* Every finger-down and finger-up, as it happens.
 *
 * raylib reads touches in its input callback and keeps only the state: a
 * finger that goes down and up between two frames leaves the state as it was,
 * and the tap is lost. RUI's desktop side catches GLFW's button callback for
 * the same reason (event_source.nim); this is the Android equivalent: wrap the
 * callback raylib set on the android_app, let raylib handle the event first,
 * then report the transition with the position raylib computed for it (in
 * screen coordinates, as GetMousePosition gives everywhere else).
 *
 * The first finger is the mouse: DOWN is it touching, UP the last finger
 * lifting. CANCEL (the system took the gesture, a back swipe say) is reported
 * as a release, as raylib treats it. */
#include <android/input.h>
#include "raylib.h"

typedef int32_t (*RuiInputFn)(struct android_app *, AInputEvent *);
typedef void (*RuiTouchCb)(int down, float x, float y);
static RuiInputFn raylibInput = NULL;
static RuiTouchCb ruiTouch = NULL;

static int32_t ruiInputWrapper(struct android_app *app, AInputEvent *event) {
  int32_t handled = raylibInput ? raylibInput(app, event) : 0;
  if (ruiTouch && AInputEvent_getType(event) == AINPUT_EVENT_TYPE_MOTION) {
    int32_t action = AMotionEvent_getAction(event) & AMOTION_EVENT_ACTION_MASK;
    if (action == AMOTION_EVENT_ACTION_DOWN || action == AMOTION_EVENT_ACTION_UP ||
        action == AMOTION_EVENT_ACTION_CANCEL) {
      Vector2 at = GetMousePosition();
      ruiTouch(action == AMOTION_EVENT_ACTION_DOWN, at.x, at.y);
    }
  }
  return handled;
}

/* Install the wrapper once raylib has set its callback (after InitWindow).
 * Returns 1 when hooked, 0 when there is no app or callback yet. */
int rui_hook_touch(RuiTouchCb cb) {
  struct android_app *app = GetAndroidApp();
  if (!app || !app->onInputEvent) return 0;
  if (app->onInputEvent != ruiInputWrapper) {
    raylibInput = app->onInputEvent;
    app->onInputEvent = ruiInputWrapper;
  }
  ruiTouch = cb;
  return 1;
}
