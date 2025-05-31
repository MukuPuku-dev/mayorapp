package com.example.myapp.utils

import android.content.Context
import android.net.Uri
import androidx.core.content.FileProvider
import com.example.myapp.R
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object ImageUtils {

    fun getTmpFileUri(context: Context): Uri {
        val tmpFile = File.createTempFile(
            "JPEG_${SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())}_",
            ".jpg",
            context.externalCacheDir // Using external cache dir
        ).apply {
            createNewFile()
            deleteOnExit() // Optional: delete when VM exits
        }
        // Ensure you use your application's authority string that matches AndroidManifest.xml
        return FileProvider.getUriForFile(context, "${context.packageName}.provider", tmpFile)
    }

    // Helper function to get path from content URI (can be complex and vary by API level)
    // For now, Compressor library might handle content URIs directly or we might need more robust solution
    // if direct file path is strictly needed by Compressor for all URI types.
    // This is a simplified version and might not work for all cases.
    fun getFileFromUri(context: Context, uri: Uri): File? {
        // For "file://" scheme
        if ("file".equals(uri.scheme, ignoreCase = true)) {
            return uri.path?.let { File(it) }
        }
        // For "content://" scheme (more complex, needs ContentResolver)
        // This is a basic attempt; a more robust solution might be needed.
        // Compressor 3.0.1 should ideally handle content URIs well.
        if ("content".equals(uri.scheme, ignoreCase = true)) {
            try {
                val inputStream = context.contentResolver.openInputStream(uri)
                val tempFile = File.createTempFile(
                    "temp_image",
                    ".${context.contentResolver.getType(uri)?.split('/')?.get(1) ?: "jpg"}", // try to get extension
                    context.cacheDir
                )
                tempFile.outputStream().use { fileOut ->
                    inputStream?.copyTo(fileOut)
                }
                inputStream?.close()
                return tempFile
            } catch (e: Exception) {
                e.printStackTrace()
                return null
            }
        }
        return null
    }
}
