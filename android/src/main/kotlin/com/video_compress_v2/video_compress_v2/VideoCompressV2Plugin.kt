package com.video_compress_v2.video_compress_v2

import android.content.Context
import android.net.Uri
import android.util.Log
import com.otaliastudios.transcoder.Transcoder
import com.otaliastudios.transcoder.TranscoderListener
import com.otaliastudios.transcoder.internal.utils.Logger
import com.otaliastudios.transcoder.source.ClipDataSource
import com.otaliastudios.transcoder.source.UriDataSource
import com.otaliastudios.transcoder.strategy.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.util.concurrent.Future

class VideoCompressV2Plugin : FlutterPlugin, MethodCallHandler, ActivityAware {

  private var context: Context? = null
  private var channel: MethodChannel? = null
  private var transcodeFuture: Future<Void>? = null
  private var activityBinding: ActivityPluginBinding? = null
  private val channelName = "video_compress"
  private val tag = "VideoCompressPlugin"

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    setupPlugin(binding.applicationContext, binding.binaryMessenger)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    teardownPlugin()
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activityBinding = binding
  }

  override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
  override fun onDetachedFromActivity() {
    activityBinding = null
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    val currentContext = context ?: run {
      result.error("INIT_ERROR", "Plugin not initialized", null)
      return
    }

    when (call.method) {
      "getByteThumbnail" -> handleThumbnailRequest(call, result, true)
      "getFileThumbnail" -> handleThumbnailRequest(call, result, false)
      "getMediaInfo" -> handleMediaInfo(call, result)
      "getCompressDir" -> handleCompressDir(currentContext, result)
      "deleteAllCache" -> handleDeleteCache(currentContext, result)
      "setLogLevel" -> handleSetLogLevel(call, result)
      "cancelCompression" -> handleCancelCompression(result)
      "compressVideo" -> handleVideoCompression(call, result)
      else -> result.notImplemented()
    }
  }

  private fun setupPlugin(context: Context, messenger: BinaryMessenger) {
    this.context = context
    channel = MethodChannel(messenger, channelName).apply {
      setMethodCallHandler(this@VideoCompressV2Plugin)
    }
  }

  private fun teardownPlugin() {
    channel?.setMethodCallHandler(null)
    channel = null
    context = null
    transcodeFuture?.cancel(true)
  }

  // region 具体处理方法
  private fun handleThumbnailRequest(call: MethodCall, result: Result, isByte: Boolean) {
    try {
      val path = requireArgument<String>(call, result, "path") ?: return
      val quality = call.argument<Int>("quality") ?: 100
      val position = call.argument<Int>("position")?.toLong() ?: 0L

      if (isByte) {
        ThumbnailUtility(channelName).getByteThumbnail(path, quality, position, result)
      } else {
        context?.let {
          ThumbnailUtility(channelName).getFileThumbnail(it, path, quality, position, result)
        } ?: result.error("NO_CONTEXT", "Context not available", null)
      }
    } catch (e: Exception) {
      result.error("THUMBNAIL_ERROR", e.message, null)
    }
  }

  private fun handleMediaInfo(call: MethodCall, result: Result) {
    try {
      val path = requireArgument<String>(call, result, "path") ?: return
      context?.let {
        result.success(Utility(channelName).getMediaInfoJson(it, path).toString())
      } ?: result.error("NO_CONTEXT", "Context not available", null)
    } catch (e: Exception) {
      result.error("MEDIA_INFO_ERROR", e.message, null)
    }
  }

  private fun handleCompressDir(context: Context, result: Result) {
    try {
      val dir = context.getExternalFilesDir("video_compress")?.absolutePath ?: run {
        result.error("STORAGE_ERROR", "Cannot access storage", null)
        return
      }
      result.success("$dir${File.separator}")
    } catch (e: Exception) {
      result.error("DIR_ERROR", e.message, null)
    }
  }

  private fun handleDeleteCache(context: Context, result: Result) {
    try {
      result.success(Utility(channelName).deleteAllCache(context))
    } catch (e: Exception) {
      result.error("CACHE_ERROR", e.message, null)
    }
  }

  private fun handleSetLogLevel(call: MethodCall, result: Result) {
    try {
      val logLevel = call.argument<Int>("logLevel") ?: Logger.LEVEL_VERBOSE
      Logger.setLogLevel(logLevel)
      result.success(true)
    } catch (e: Exception) {
      result.error("LOG_ERROR", e.message, null)
    }
  }

  private fun handleCancelCompression(result: Result) {
    try {
      transcodeFuture?.cancel(true)
      result.success(true)
    } catch (e: Exception) {
      result.error("CANCEL_ERROR", e.message, null)
    }
  }

  private fun handleVideoCompression(call: MethodCall, result: Result) {
    try {
      val path = requireArgument<String>(call, result, "path") ?: return
      val quality = call.argument<Int>("quality") ?: 0
      val frameRate = call.argument<Int>("frameRate") ?: 30
      val uniqueId = requireArgument<String>(call, result, "unique") ?: return
      val deleteOrigin = call.argument<Boolean>("deleteOrigin") ?: false
      val startTime = call.argument<Int>("startTime")
      val duration = call.argument<Int>("duration")
      val includeAudio = call.argument<Boolean>("includeAudio") ?: true

      val videoStrategy = when (quality) {
        0 -> DefaultVideoStrategy.atMost(720).build()
        1 -> DefaultVideoStrategy.atMost(360).build()
        2 -> DefaultVideoStrategy.atMost(640).build()
        3 -> DefaultVideoStrategy.Builder()
          .keyFrameInterval(3f)
          .bitRate((1280 * 720 * 4).toLong())
          .frameRate(frameRate)
          .build()
        4 -> DefaultVideoStrategy.atMost(480, 640).build()
        5 -> DefaultVideoStrategy.atMost(540, 960).build()
        6 -> DefaultVideoStrategy.atMost(720, 1280).build()
        7 -> DefaultVideoStrategy.atMost(1080, 1920).build()
        else -> DefaultVideoStrategy.atMost(1080, 1920).build()
      }

      val audioStrategy = if (includeAudio) {
        DefaultAudioStrategy.builder()
          .channels(DefaultAudioStrategy.CHANNELS_AS_INPUT)
          .sampleRate(DefaultAudioStrategy.SAMPLE_RATE_AS_INPUT)
          .build()
      } else {
        RemoveTrackStrategy()
      }

      val destPath = getDestinationPath(path)
      val dataSource = createDataSource(path, startTime, duration)

      transcodeFuture = Transcoder.into(destPath)
        .addDataSource(dataSource)
        .setVideoTrackStrategy(videoStrategy)
        .setAudioTrackStrategy(audioStrategy)
        .setListener(createTranscodeListener(uniqueId, result, destPath, deleteOrigin))
        .transcode()

    } catch (e: Exception) {
      result.error("COMPRESS_ERROR", e.message, null)
    }
  }
  // endregion

  // region 工具方法
  private inline fun <reified T> requireArgument(call: MethodCall, result: Result, key: String): T? {
    return call.argument<T>(key) ?: run {
      result.error("MISSING_ARG", "Required argument '$key' is missing", null)
      null
    }
  }

  private fun getDestinationPath(originalPath: String): String {
    return context?.getExternalFilesDir("video_compress")
      ?.absolutePath
      ?.plus(File.separator)
      ?.plus(originalPath.hashCode())
      ?.plus(".mp4")
      ?: throw IllegalStateException("Storage directory not available")
  }

  private fun createDataSource(path: String, startTime: Int?, duration: Int?): ClipDataSource {
    val uri = Uri.parse(path)
    val baseSource = UriDataSource(context ?: throw IllegalStateException("Context not available"), uri)

    return if (startTime != null || duration != null) {
      ClipDataSource(
        baseSource,
        (startTime ?: 0) * 1000L,
        (duration ?: 0) * 1000L
      )
    } else {
      ClipDataSource(baseSource, 0L, baseSource.durationUs)
    }
  }

  private fun createTranscodeListener(
    uniqueId: String,
    result: Result,
    destPath: String,
    deleteOrigin: Boolean
  ): TranscoderListener = object : TranscoderListener {
    override fun onTranscodeProgress(progress: Double) {
      channel?.invokeMethod("updateProgress", mapOf(
        "progress" to (progress * 100).toInt(),
        "unique" to uniqueId
      ))
    }

    override fun onTranscodeCompleted(successCode: Int) {
      context?.let { ctx ->
        val mediaInfo = Utility(channelName).getMediaInfoJson(ctx, destPath).apply {
          put("isCancel", false)
        }
        if (deleteOrigin) File(destPath).delete()
        result.success(mediaInfo.toString())
      } ?: result.error("CONTEXT_LOST", "Context not available", null)
    }

    override fun onTranscodeCanceled() {
      result.success(null)
    }

    override fun onTranscodeFailed(exception: Throwable) {
      result.error("TRANSCODE_FAILED", exception.message ?: "Unknown error", null)
    }
  }
  // endregion
}