/*
 * JNI glue: com.fluxhome.app.bridge.FluxIceNative  <->  flux_ice_mobile.
 *
 * Thin, per app ADR-0001: the data plane stays in C (external + loopback
 * sockets); Kotlin/Dart only drive this control surface. State is *polled*
 * (nativeState) rather than pushed via a JNI callback, to avoid attaching
 * libjuice's worker thread to the JVM.
 */
#include <jni.h>
#include <stdlib.h>
#include <string.h>

#include "flux_ice/flux_ice_mobile.h"

/* Handle = a small wrapper holding the session + the offer captured at start. */
typedef struct {
    flux_ice_mobile_session_t *s;
    char offer[4096];
} jni_session_t;

JNIEXPORT jlong JNICALL
Java_com_fluxhome_app_bridge_FluxIceNative_nativeStart(JNIEnv *env, jobject thiz,
                                                       jstring stun_host, jint stun_port) {
    (void)thiz;
    jni_session_t *w = calloc(1, sizeof(*w));
    if (!w) return 0;

    const char *stun = NULL;
    if (stun_host) stun = (*env)->GetStringUTFChars(env, stun_host, NULL);

    w->s = flux_ice_mobile_start(stun, (uint16_t)stun_port,
                                 w->offer, sizeof(w->offer), NULL, NULL);

    if (stun) (*env)->ReleaseStringUTFChars(env, stun_host, stun);

    if (!w->s) { free(w); return 0; }
    return (jlong)(intptr_t)w;
}

JNIEXPORT jstring JNICALL
Java_com_fluxhome_app_bridge_FluxIceNative_nativeOffer(JNIEnv *env, jobject thiz, jlong handle) {
    (void)thiz;
    jni_session_t *w = (jni_session_t *)(intptr_t)handle;
    return (*env)->NewStringUTF(env, w ? w->offer : "");
}

JNIEXPORT jint JNICALL
Java_com_fluxhome_app_bridge_FluxIceNative_nativeSetAnswer(JNIEnv *env, jobject thiz,
                                                           jlong handle, jstring answer) {
    (void)thiz;
    jni_session_t *w = (jni_session_t *)(intptr_t)handle;
    if (!w || !w->s || !answer) return -1;
    const char *a = (*env)->GetStringUTFChars(env, answer, NULL);
    int rc = flux_ice_mobile_set_answer(w->s, a);
    (*env)->ReleaseStringUTFChars(env, answer, a);
    return rc;
}

JNIEXPORT jint JNICALL
Java_com_fluxhome_app_bridge_FluxIceNative_nativeLocalPort(JNIEnv *env, jobject thiz, jlong handle) {
    (void)env; (void)thiz;
    jni_session_t *w = (jni_session_t *)(intptr_t)handle;
    return w ? (jint)flux_ice_mobile_local_port(w->s) : 0;
}

JNIEXPORT jint JNICALL
Java_com_fluxhome_app_bridge_FluxIceNative_nativeState(JNIEnv *env, jobject thiz, jlong handle) {
    (void)env; (void)thiz;
    jni_session_t *w = (jni_session_t *)(intptr_t)handle;
    return w ? (jint)flux_ice_mobile_state(w->s) : -1;
}

JNIEXPORT void JNICALL
Java_com_fluxhome_app_bridge_FluxIceNative_nativeStop(JNIEnv *env, jobject thiz, jlong handle) {
    (void)env; (void)thiz;
    jni_session_t *w = (jni_session_t *)(intptr_t)handle;
    if (!w) return;
    flux_ice_mobile_stop(w->s);
    free(w);
}
