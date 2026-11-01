package com.maison.homeview;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.res.Configuration;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.TextView;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;

public class MainActivity extends Activity {

    private static final String DB_FILENAME = "homeview_secure_database.json";
    private WebView webView;

    @SuppressLint({"SetJavaScriptEnabled", "AddJavascriptInterface"})
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        try {
            Window window = getWindow();
            if (window != null) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    try {
                        window.setStatusBarColor(Color.parseColor("#0B0F19"));
                        window.setNavigationBarColor(Color.parseColor("#0B0F19"));
                    } catch (Throwable ignored) {
                    }
                }
            }

            webView = new WebView(this);
            webView.setBackgroundColor(Color.parseColor("#0B0F19"));
            // IMPORTANT sur Honor MagicOS / Huawei EMUI : toujours appeler setContentView AVANT enableImmersiveFullscreen()
            setContentView(webView);

            webView.post(new Runnable() {
                @Override
                public void run() {
                    enableImmersiveFullscreen();
                }
            });

            WebSettings settings = webView.getSettings();
            settings.setJavaScriptEnabled(true);
            settings.setDomStorageEnabled(true);
            settings.setDatabaseEnabled(true);
            settings.setAllowFileAccess(true);
            settings.setAllowContentAccess(true);
            settings.setLoadWithOverviewMode(true);
            settings.setUseWideViewPort(true);
            settings.setCacheMode(WebSettings.LOAD_DEFAULT);

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                try {
                    settings.setAllowFileAccessFromFileURLs(true);
                    settings.setAllowUniversalAccessFromFileURLs(true);
                } catch (Throwable ignored) {
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                try {
                    settings.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
                } catch (Throwable ignored) {
                }
            }

            // Note : NE PAS appeler setSafeBrowsingEnabled(true) car cela fait planter WebView sur certaines tablettes Honor/Huawei

            webView.addJavascriptInterface(new AndroidBridge(), "AndroidHomeView");

            webView.setWebChromeClient(new WebChromeClient());
            webView.setWebViewClient(new WebViewClient() {
                @Override
                public boolean shouldOverrideUrlLoading(WebView view, String url) {
                    if (url != null && (url.startsWith("file:///android_asset/") || url.startsWith("about:"))) {
                        return false;
                    }
                    return true;
                }
            });

            webView.loadUrl("file:///android_asset/index.html");
        } catch (Throwable e) {
            TextView errorView = new TextView(this);
            errorView.setBackgroundColor(Color.parseColor("#0B0F19"));
            errorView.setTextColor(Color.WHITE);
            errorView.setGravity(Gravity.CENTER);
            errorView.setPadding(48, 48, 48, 48);
            errorView.setText("HomeView — Initialisation WebView :\n" + e.getMessage());
            setContentView(errorView);
        }
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        enableImmersiveFullscreen();
        if (webView != null && newConfig != null) {
            final String mode = (newConfig.orientation == Configuration.ORIENTATION_PORTRAIT)
                    ? "portrait"
                    : "landscape";
            webView.post(new Runnable() {
                @Override
                public void run() {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                        webView.evaluateJavascript(
                                "if (window.detectAndApplyOrientation) { window.detectAndApplyOrientation('" + mode + "'); }",
                                null
                        );
                    } else {
                        webView.loadUrl("javascript:if(window.detectAndApplyOrientation){window.detectAndApplyOrientation('" + mode + "');}");
                    }
                }
            });
        }
    }

    private void enableImmersiveFullscreen() {
        try {
            Window window = getWindow();
            if (window == null) return;
            View decorView = window.getDecorView();
            if (decorView == null) return;

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                WindowInsetsController controller = window.getInsetsController();
                if (controller != null) {
                    controller.hide(WindowInsets.Type.statusBars() | WindowInsets.Type.navigationBars());
                    controller.setSystemBarsBehavior(
                            WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                    );
                    return;
                }
            }
            decorView.setSystemUiVisibility(
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                            | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_FULLSCREEN
            );
        } catch (Throwable ignored) {
        }
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            enableImmersiveFullscreen();
        }
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) {
            webView.goBack();
        }
    }

    public class AndroidBridge {
        @JavascriptInterface
        public boolean saveDatabase(String jsonPayload) {
            if (jsonPayload == null) return false;
            FileOutputStream fos = null;
            try {
                File file = new File(getFilesDir(), DB_FILENAME);
                fos = new FileOutputStream(file, false);
                fos.write(jsonPayload.getBytes("UTF-8"));
                fos.flush();
                return true;
            } catch (Exception e) {
                return false;
            } finally {
                if (fos != null) {
                    try {
                        fos.close();
                    } catch (Exception ignored) {
                    }
                }
            }
        }

        @JavascriptInterface
        public String loadDatabase() {
            FileInputStream fis = null;
            ByteArrayOutputStream bos = null;
            try {
                File file = new File(getFilesDir(), DB_FILENAME);
                if (!file.exists()) {
                    return "";
                }
                fis = new FileInputStream(file);
                bos = new ByteArrayOutputStream();
                byte[] buffer = new byte[4096];
                int read;
                while ((read = fis.read(buffer)) != -1) {
                    bos.write(buffer, 0, read);
                }
                return bos.toString("UTF-8");
            } catch (Exception e) {
                return "";
            } finally {
                if (fis != null) {
                    try {
                        fis.close();
                    } catch (Exception ignored) {
                    }
                }
                if (bos != null) {
                    try {
                        bos.close();
                    } catch (Exception ignored) {
                    }
                }
            }
        }
    }
}
