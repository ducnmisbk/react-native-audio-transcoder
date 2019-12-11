package com.rnaudiotranscoder;

import android.util.Log;

import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.Arguments;

import java.io.File;

import io.microshow.rxffmpeg.RxFFmpegInvoke;
import io.microshow.rxffmpeg.RxFFmpegSubscriber;


public final class RNAudioTranscoder extends ReactContextBaseJavaModule {

    public final String COMMAND_FORMAT = "ffmpeg -loop 1 -i %s -i %s -c:a copy -c:v libx264 -shortest %s";
    public final String TAG = "RNAudioTranscoder";

    public RNAudioTranscoder(final ReactApplicationContext context) {
        super(context);
    }

    @Override
    public final String getName() {
        return "RNAudioTranscoder";
    }

    @ReactMethod
    public final void transcode(final ReadableMap options, final Promise promise) {
        final Optional<String> paramErrors = this.checkRequiredOptions(options);
        if (paramErrors.exists) {
            promise.reject(paramErrors.value);
        } else {
            final String input = options.getString("input");
            final String output = options.getString("output");
            String[] commands = this.createFFmpegCommand(input, output);

            File fDelete = new File(output);
            if (fDelete.exists()) {
                fDelete.delete();
            }

            RxFFmpegInvoke.getInstance().runCommandRxJava(commands).subscribe(new RxFFmpegSubscriber() {
                @Override
                public void onFinish() {
                    File fDelete = new File(input);
                    if (fDelete.exists()) {
                        fDelete.delete();
                    }
                    RxFFmpegInvoke.getInstance().exit();
                    promise.resolve(makeMessagePayload("onFinish"));
                }

                @Override
                public void onProgress(int progress, long progressTime) {
                }

                @Override
                public void onCancel() {
                    promise.reject("onCancel");
                }

                @Override
                public void onError(String message) {
                    promise.reject(message);
                }
            });
        }
    }

    private final ReadableMap makeMessagePayload(final String message) {
        final WritableMap payload = Arguments.createMap();
        payload.putString("message", message);
        return payload;
    }

    private final String[] createFFmpegCommand(final String input, final String output) {
        String imagePath = "/data/user/0/com.unitive.artistapp/files/sound_only.png";
        return String.format(COMMAND_FORMAT, imagePath, input, output).split(" ");
    }

    private final Optional<String> checkRequiredOptions(final ReadableMap options) {
        if (!options.hasKey("input")) return Optional.of("Missing required parameter 'input'");
        if (!options.hasKey("output"))
            return Optional.of("Missing required parameter 'output'");

        return Optional.empty();
    }
}
