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
