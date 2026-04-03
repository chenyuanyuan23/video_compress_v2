package com.video_compress_v2.video_compress_v2

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.io.FileInputStream
import kotlin.math.max


class Utility(private val channelName: String) {

    private fun isLandscapeImage(orientation: Int) = orientation != 90 && orientation != 270

    fun deleteFile(file: File) {
        if (file.exists()) {
            file.delete()
        }
    }

    fun timeStrToTimestamp(time: String): Long {
        val timeArr = time.split(":")
        val hour = Integer.parseInt(timeArr[0])
        val min = Integer.parseInt(timeArr[1])
        val secArr = timeArr[2].split(".")
        val sec = Integer.parseInt(secArr[0])
        val mSec = Integer.parseInt(secArr[1])

        val timeStamp = (hour * 3600 + min * 60 + sec) * 1000 + mSec
        return timeStamp.toLong()
    }

    fun getMediaInfoJson(context: Context, path: String): JSONObject {
        val file = File(path)
        val retriever = MediaMetadataRetriever()

        retriever.setDataSource(context, Uri.fromFile(file))

        val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
        val title = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE) ?: ""
        val author = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_AUTHOR) ?: ""
        var widthStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
        var heightStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
        val orientation =
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
        val ori = orientation?.toIntOrNull()
        val frameData: Bitmap? =
            retriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_NEXT_SYNC)
        if (frameData != null) {
            widthStr = frameData.getWidth().toString()
            heightStr = frameData.getHeight().toString()
            frameData.recycle() // 释放 Bitmap 对象的内存
        } else {
            if (ori != null && (ori == 90 || ori == 270)) {
                // 有旋转高宽需要互换
                val tmp = widthStr
                widthStr = heightStr
                heightStr = tmp
            }
        }

        val duration = java.lang.Long.parseLong(durationStr ?: "0")
        var width = java.lang.Long.parseLong(widthStr ?: "0")
        var height = java.lang.Long.parseLong(heightStr ?: "0")
        val filesize = file.length()

        retriever.release()

        val json = JSONObject()

        json.put("path", path)
        json.put("title", title)
        json.put("author", author)
        json.put("width", width)
        json.put("height", height)
        json.put("duration", duration)
        json.put("filesize", filesize)
        if (ori != null) {
            json.put("orientation", ori)
        }

        return json
    }

    private fun setDataSource(videoPath: String, retriever: MediaMetadataRetriever) {

        val path: String = if (videoPath.startsWith("/")) {
            videoPath
        } else if (videoPath.startsWith("file://")) {
            videoPath.substring(7)
        } else {
            retriever.setDataSource(videoPath)
            return
        }

        val videoFile = File(path)
        FileInputStream(videoFile.absolutePath).use { inputStream ->
            retriever.setDataSource(inputStream.fd)
        }
    }

    fun getBitmap(path: String, position: Long, result: MethodChannel.Result): Bitmap {
        var bitmap: Bitmap? = null
        val retriever = MediaMetadataRetriever()

        try {
            setDataSource(path, retriever)
            bitmap = retriever.getFrameAtTime(position, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
        } catch (ex: IllegalArgumentException) {
            result.error(channelName, "Assume this is a corrupt video file", null)
        } catch (ex: RuntimeException) {
            result.error(channelName, "Assume this is a corrupt video file", null)
        } finally {
            try {
                retriever.release()
            } catch (ex: RuntimeException) {
                result.error(channelName, "Ignore failures while cleaning up", null)
            }
        }

        if (bitmap == null) result.success(emptyArray<Int>())

        val width = bitmap!!.width
        val height = bitmap.height
        val max = max(width, height)
        if (max > 512) {
            val scale = 512f / max
            val w = Math.round(scale * width)
            val h = Math.round(scale * height)
            val originalBitmap = bitmap
            bitmap = Bitmap.createScaledBitmap(originalBitmap, w, h, true)
            // 回收原始 Bitmap 防止内存泄漏
            if (originalBitmap != bitmap) {
                originalBitmap.recycle()
            }
        }

        return bitmap!!
    }

    fun getFileNameWithGifExtension(path: String): String {
        val file = File(path)
        var fileName = ""
        val gifSuffix = "gif"
        val dotGifSuffix = ".$gifSuffix"

        if (file.exists()) {
            val name = file.name
            fileName = name.replaceAfterLast(".", gifSuffix)

            if (!fileName.endsWith(dotGifSuffix)) {
                fileName += dotGifSuffix
            }
        }
        return fileName
    }

    fun deleteAllCache(context: Context): Boolean {
        val dir = context.getExternalFilesDir("video_compress")
        return dir?.deleteRecursively() == true
    }
}