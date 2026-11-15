package com.edinaldo.volei

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.edinaldo.volei/installer"

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val h = window.decorView.height
            val w = window.decorView.width
            if (h > 0 && w > 0) {
                // Protege a área do joystick virtual no canto inferior esquerdo dos gestos do sistema Android (ex: voltar / navegação por gestos)
                val exclusionRect = android.graphics.Rect(0, h / 2, w / 3, h)
                window.decorView.systemGestureExclusionRects = listOf(exclusionRect)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestPackageInstalls" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(packageManager.canRequestPackageInstalls())
                    } else {
                        result.success(true)
                    }
                }
                "openInstallPermissionSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SETTINGS_ERROR", e.message, null)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrBlank()) {
                        result.error("INVALID_PATH", "O caminho do arquivo APK não pode ser nulo.", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val apkFile = File(filePath)
                        if (!apkFile.exists() || apkFile.length() == 0L) {
                            result.error("FILE_NOT_FOUND", "Arquivo APK não encontrado ou vazio em $filePath", null)
                            return@setMethodCallHandler
                        }

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            if (!packageManager.canRequestPackageInstalls()) {
                                val settingsIntent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                    data = Uri.parse("package:$packageName")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(settingsIntent)
                                result.error("PERMISSION_DENIED", "Permissão para instalar apps desconhecidos não concedida.", null)
                                return@setMethodCallHandler
                            }
                        }

                        val authority = "$packageName.fileprovider"
                        val apkUri = FileProvider.getUriForFile(
                            applicationContext,
                            authority,
                            apkFile
                        )

                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }

                        // Concede permissão explícita aos instaladores de pacote do Android e da Samsung
                        val installerPackages = listOf(
                            "com.google.android.packageinstaller",
                            "com.android.packageinstaller",
                            "com.samsung.android.packageinstaller"
                        )
                        for (pkg in installerPackages) {
                            try {
                                grantUriPermission(pkg, apkUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            } catch (_: Exception) {}
                        }

                        // Consulta todas as atividades do sistema que abrem pacotes APK
                        try {
                            val resInfoList = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                packageManager.queryIntentActivities(
                                    intent,
                                    PackageManager.ResolveInfoFlags.of(0)
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                packageManager.queryIntentActivities(intent, 0)
                            }
                            for (resolveInfo in resInfoList) {
                                val pkg = resolveInfo.activityInfo.packageName
                                grantUriPermission(pkg, apkUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                        } catch (_: Exception) {}

                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
