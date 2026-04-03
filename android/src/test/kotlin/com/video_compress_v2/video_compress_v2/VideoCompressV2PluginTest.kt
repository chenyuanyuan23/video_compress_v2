package com.video_compress_v2.video_compress_v2

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import org.mockito.Mockito

/**
 * VideoCompressV2Plugin 单元测试
 */
internal class VideoCompressV2PluginTest {

    @Test
    fun onMethodCall_getMediaInfo_withoutContext_returnsError() {
        val plugin = VideoCompressV2Plugin()

        val call = MethodCall("getMediaInfo", mapOf("path" to "/test/video.mp4"))
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        // 由于没有初始化 context，应该返回 INIT_ERROR
        Mockito.verify(mockResult).error(
            Mockito.eq("INIT_ERROR"),
            Mockito.anyString(),
            Mockito.isNull()
        )
    }

    @Test
    fun onMethodCall_compressVideo_withoutContext_returnsError() {
        val plugin = VideoCompressV2Plugin()

        val call = MethodCall("compressVideo", mapOf(
            "path" to "/test/video.mp4",
            "unique" to "test123"
        ))
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        // 由于没有初始化 context，应该返回 INIT_ERROR
        Mockito.verify(mockResult).error(
            Mockito.eq("INIT_ERROR"),
            Mockito.anyString(),
            Mockito.isNull()
        )
    }
}
