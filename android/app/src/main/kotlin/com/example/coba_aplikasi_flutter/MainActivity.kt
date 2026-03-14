package com.example.coba_aplikasi_flutter

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.net.Uri
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.util.concurrent.Executors

import android.util.Log
import android.app.Activity
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.coba_aplikasi_flutter/image_processing"
    private val TAG = "NativeKotlin"
    private val executor = Executors.newSingleThreadExecutor()
    private var sharedImagePaths: MutableList<String> = mutableListOf()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        if (Intent.ACTION_SEND == intent.action && intent.type?.startsWith("image/") == true) {
            Log.d(TAG, "Menerima Shared Intent (single) dari aplikasi lain!")
            (intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))?.let { uri ->
                val path = copyUriToCache(uri)
                if (path != null) {
                    sharedImagePaths.clear()
                    sharedImagePaths.add(path)
                }
            }
        } else if (Intent.ACTION_SEND_MULTIPLE == intent.action && intent.type?.startsWith("image/") == true) {
            Log.d(TAG, "Menerima Shared Intent (multiple) dari aplikasi lain!")
            val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            if (uris != null) {
                sharedImagePaths.clear()
                for (uri in uris) {
                    val path = copyUriToCache(uri)
                    if (path != null) sharedImagePaths.add(path)
                }
            }
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        try {
            val inputStream: InputStream? = contentResolver.openInputStream(uri)
            val file = File(cacheDir, "shared_image_${System.currentTimeMillis()}.jpg")
            val outputStream = FileOutputStream(file)
            inputStream?.use { input ->
                outputStream.use { output ->
                    input.copyTo(output)
                }
            }
            return file.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "applyFilter" -> {
                    val path = call.argument<String>("path")
                    val type = call.argument<String>("type")
                    
                    Log.d(TAG, "Panggilan dari Flutter diterima: applyFilter type=$type")

                    if (path != null && type != null) {
                        executor.execute {
                            try {
                                val start = System.currentTimeMillis()
                                val newPath = applyFilter(path, type)
                                val duration = System.currentTimeMillis() - start
                                Log.d(TAG, "Filter berhasil diterapkan di Kotlin dalam ${duration}ms")
                                runOnUiThread { result.success(newPath) }
                            } catch (e: Exception) {
                                Log.e(TAG, "Error di Kotlin: ${e.message}")
                                runOnUiThread { result.error("PROCESSING_ERROR", e.message, null) }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENTS", "Path or type is null", null)
                    }
                }
                "getSharedImage" -> {
                    // Legacy single image support
                    val path = if (sharedImagePaths.isNotEmpty()) sharedImagePaths[0] else null
                    result.success(path)
                }
                "getSharedImages" -> {
                    if (sharedImagePaths.isNotEmpty()) {
                        Log.d(TAG, "Flutter meminta shared images. Ada ${sharedImagePaths.size} gambar")
                    }
                    val paths = sharedImagePaths.toList()
                    sharedImagePaths.clear()
                    result.success(if (paths.isNotEmpty()) paths else null)
                }
                "scanDocument" -> {
                    Log.d(TAG, "Memulai scan dokumen via ML Kit Native")
                    startDocumentScanner(result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private var pendingResult: MethodChannel.Result? = null

    private val scannerLauncher = registerForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val resultData = GmsDocumentScanningResult.fromActivityResultIntent(result.data)
            

            val pages = resultData?.pages?.mapNotNull { page ->
                page.imageUri?.let { uri -> copyUriToCache(uri) }
            } ?: emptyList()
            
            Log.d(TAG, "Scan berhasil! Dapat ${pages.size} halaman")
            pendingResult?.success(pages)
        } else {
            Log.d(TAG, "Scan dibatalkan atau gagal")
            pendingResult?.success(null)
        }
        pendingResult = null
    }

    private fun startDocumentScanner(result: MethodChannel.Result) {
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()

        val scanner = GmsDocumentScanning.getClient(options)
        
        scanner.getStartScanIntent(this)
            .addOnSuccessListener { intentSender ->
                pendingResult = result
                scannerLauncher.launch(IntentSenderRequest.Builder(intentSender).build())
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Gagal memulai scanner: ${e.message}")
                result.error("SCAN_ERROR", "Gagal memulai scanner: ${e.message}", null)
            }
    }

    private fun applyFilter(path: String, type: String): String {
        val originalBitmap = BitmapFactory.decodeFile(path) ?: throw Exception("Failed to decode image")
        
        val processedBitmap = when (type) {
            "gray" -> toGrayscale(originalBitmap)
            "bw" -> toBlackAndWhite(originalBitmap)
            "magic" -> toMagicColor(originalBitmap)
            else -> originalBitmap
        }

        return saveBitmap(processedBitmap, path, type)
    }

    private fun toGrayscale(bmpOriginal: Bitmap): Bitmap {
        val width = bmpOriginal.width
        val height = bmpOriginal.height
        val bmpGrayscale = Bitmap.createBitmap(width, height, Bitmap.Config.RGB_565)
        val c = Canvas(bmpGrayscale)
        val paint = Paint()
        val cm = ColorMatrix()
        cm.setSaturation(0f)
        val f = ColorMatrixColorFilter(cm)
        paint.colorFilter = f
        c.drawBitmap(bmpOriginal, 0f, 0f, paint)
        return bmpGrayscale
    }

    private fun toBlackAndWhite(bmpOriginal: Bitmap): Bitmap {
        val gray = toGrayscale(bmpOriginal)
        val width = gray.width
        val height = gray.height
        val pixels = IntArray(width * height)
        gray.getPixels(pixels, 0, width, 0, 0, width, height)

        val threshold = 128

        for (i in pixels.indices) {
            val color = pixels[i]
            val r = (color shr 16) and 0xFF
            pixels[i] = if (r > threshold) -0x1 else -0x1000000
        }

        val bwBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.RGB_565)
        bwBitmap.setPixels(pixels, 0, width, 0, 0, width, height)
        return bwBitmap
    }

    private fun toMagicColor(bmpOriginal: Bitmap): Bitmap {
        val width = bmpOriginal.width
        val height = bmpOriginal.height
        val bmpMagic = Bitmap.createBitmap(width, height, Bitmap.Config.RGB_565)
        
        val c = Canvas(bmpMagic)
        val paint = Paint()
        
        val cm = ColorMatrix()
        val contrast = 1.3f
        val brightness = 15f
        cm.set(floatArrayOf(
            contrast, 0f, 0f, 0f, brightness,
            0f, contrast, 0f, 0f, brightness,
            0f, 0f, contrast, 0f, brightness,
            0f, 0f, 0f, 1f, 0f
        ))
        
        val satMatrix = ColorMatrix()
        satMatrix.setSaturation(1.2f)
        cm.postConcat(satMatrix)

        paint.colorFilter = ColorMatrixColorFilter(cm)
        c.drawBitmap(bmpOriginal, 0f, 0f, paint)
        return bmpMagic
    }

    private fun saveBitmap(bitmap: Bitmap, originalPath: String, suffix: String): String {
        val file = File(originalPath)
        val parent = file.parent
        val name = file.nameWithoutExtension
        val newFile = File(parent, "${name}_${suffix}.jpg")
        
        val out = FileOutputStream(newFile)
        bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
        out.flush()
        out.close()
        
        return newFile.absolutePath
    }
}
