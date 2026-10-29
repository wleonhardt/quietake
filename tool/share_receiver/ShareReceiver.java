package com.example.quietake.sharefixture;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.widget.TextView;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;

/** Disposable, offline recipient. Never included in the Quietake APK. */
public final class ShareReceiver extends Activity {
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        final TextView text = new TextView(this);
        text.setText("Checking granted copies…");
        setContentView(text);
        final Intent intent = getIntent();
        new Thread(() -> {
            JSONObject result = new JSONObject();
            try {
                // Read after the sender's chosen-app callback, not at selection time.
                Thread.sleep(1000);
                ArrayList<Uri> files = new ArrayList<>();
                if (Intent.ACTION_SEND_MULTIPLE.equals(intent.getAction())) {
                    files = intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM);
                } else if (Intent.ACTION_SEND.equals(intent.getAction())) {
                    Uri single = intent.getParcelableExtra(Intent.EXTRA_STREAM);
                    if (single != null) files.add(single);
                }
                if (files == null || files.isEmpty() || files.size() > 10) throw new IllegalArgumentException();
                JSONArray received = new JSONArray();
                for (Uri uri : files) {
                    if (!"content".equals(uri.getScheme())) throw new IllegalArgumentException();
                    MessageDigest digest = MessageDigest.getInstance("SHA-256");
                    long count = 0;
                    try (InputStream input = getContentResolver().openInputStream(uri)) {
                        byte[] buffer = new byte[65536];
                        int length;
                        while ((length = input.read(buffer)) != -1) {
                            count += length;
                            if (count > 64L * 1024 * 1024) throw new IllegalArgumentException();
                            digest.update(buffer, 0, length);
                        }
                    }
                    StringBuilder hash = new StringBuilder();
                    for (byte b : digest.digest()) hash.append(String.format("%02x", b & 255));
                    JSONObject item = new JSONObject();
                    item.put("bytes", count);
                    item.put("sha256", hash.toString());
                    item.put("mime", getContentResolver().getType(uri));
                    received.put(item);
                }
                result.put("files", received);
                result.put("package", getPackageName());
            } catch (Exception error) {
                try { result.put("error", "Could not read granted copies"); } catch (Exception ignored) {}
            }
            try (FileOutputStream output = new FileOutputStream(new File(getFilesDir(), "receipt.json"))) {
                output.write(result.toString().getBytes(StandardCharsets.UTF_8));
            } catch (Exception ignored) {}
            runOnUiThread(() -> text.setText("Receipt ready. Return to Quietake with Back."));
        }).start();
    }
}
