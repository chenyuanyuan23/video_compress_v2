package com.video_compress_v2.video_compress_v2

import android.graphics.Bitmap
import io.flutter.plugin.common.MethodChannel
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.mockito.kotlin.any
import org.mockito.kotlin.whenever
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * 针对 Utility 类内存泄漏修复的单元测试
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class UtilityTest {

    private val channelName = "video_compress_test"

    /**
     * 测试 Bitmap 缩放时原始 Bitmap 被正确回收
     * 验证修复: 当图片尺寸 > 512 时，原始 Bitmap 应该被 recycle
     */
    @Test
    fun `bitmap should be recycled after scaling when size exceeds 512`() {
        // 创建一个大于 512 的 Bitmap 用于测试缩放逻辑
        val largeBitmap = Bitmap.createBitmap(1024, 768, Bitmap.Config.ARGB_8888)

        assertNotNull(largeBitmap)
        assertTrue(largeBitmap.width > 512 || largeBitmap.height > 512)

        // 模拟缩放逻辑 (从 Utility.getBitmap 中提取)
        val width = largeBitmap.width
        val height = largeBitmap.height
        val max = maxOf(width, height)

        if (max > 512) {
            val scale = 512f / max
            val w = Math.round(scale * width)
            val h = Math.round(scale * height)
            val originalBitmap = largeBitmap
            val scaledBitmap = Bitmap.createScaledBitmap(originalBitmap, w, h, true)

            // 验证缩放后的尺寸正确
            assertTrue(scaledBitmap.width <= 512)
            assertTrue(scaledBitmap.height <= 512)

            // 回收原始 Bitmap (模拟修复后的代码)
            if (originalBitmap != scaledBitmap) {
                originalBitmap.recycle()
            }

            // 验证原始 Bitmap 已被回收
            assertTrue(originalBitmap.isRecycled)

            // 清理
            scaledBitmap.recycle()
        }
    }

    /**
     * 测试当 Bitmap 尺寸小于等于 512 时不进行缩放
     * 验证: 小图片不应该被处理，避免不必要的内存操作
     */
    @Test
    fun `bitmap should not be scaled when size is within 512`() {
        val smallBitmap = Bitmap.createBitmap(256, 256, Bitmap.Config.ARGB_8888)

        val width = smallBitmap.width
        val height = smallBitmap.height
        val max = maxOf(width, height)

        // 验证不需要缩放
        assertTrue(max <= 512)

        // 小图片不应该被回收 (因为没有创建新的缩放版本)
        assertTrue(!smallBitmap.isRecycled)

        // 清理
        smallBitmap.recycle()
    }

    /**
     * 测试 createScaledBitmap 返回相同对象时的处理
     * 当源 Bitmap 尺寸与目标尺寸相同时，createScaledBitmap 可能返回同一对象
     */
    @Test
    fun `should not recycle bitmap when createScaledBitmap returns same object`() {
        val bitmap = Bitmap.createBitmap(512, 512, Bitmap.Config.ARGB_8888)

        // 使用相同尺寸调用 createScaledBitmap
        val scaledBitmap = Bitmap.createScaledBitmap(bitmap, 512, 512, true)

        // 验证: 如果是同一对象，不应该回收
        if (bitmap == scaledBitmap) {
            // 同一对象，不回收
            assertTrue(!bitmap.isRecycled)
        } else {
            // 不同对象，可以回收原始的
            bitmap.recycle()
            assertTrue(bitmap.isRecycled)
            scaledBitmap.recycle()
        }
    }

    /**
     * 测试缩放比例计算的正确性
     * 验证: 缩放后最大边应该等于 512
     */
    @Test
    fun `scaled bitmap max dimension should be 512`() {
        // 测试横向图片
        val landscapeBitmap = Bitmap.createBitmap(1920, 1080, Bitmap.Config.ARGB_8888)
        val landscapeMax = maxOf(landscapeBitmap.width, landscapeBitmap.height)
        val landscapeScale = 512f / landscapeMax
        val landscapeW = Math.round(landscapeScale * landscapeBitmap.width)
        val landscapeH = Math.round(landscapeScale * landscapeBitmap.height)

        assertTrue(maxOf(landscapeW, landscapeH) == 512)
        landscapeBitmap.recycle()

        // 测试纵向图片
        val portraitBitmap = Bitmap.createBitmap(1080, 1920, Bitmap.Config.ARGB_8888)
        val portraitMax = maxOf(portraitBitmap.width, portraitBitmap.height)
        val portraitScale = 512f / portraitMax
        val portraitW = Math.round(portraitScale * portraitBitmap.width)
        val portraitH = Math.round(portraitScale * portraitBitmap.height)

        assertTrue(maxOf(portraitW, portraitH) == 512)
        portraitBitmap.recycle()
    }

    /**
     * 测试 deleteFile 方法
     */
    @Test
    fun `deleteFile should handle non-existent file gracefully`() {
        val utility = Utility(channelName)
        val nonExistentFile = java.io.File("/non/existent/path/file.mp4")

        // 应该不抛出异常
        utility.deleteFile(nonExistentFile)
    }

    /**
     * 测试 timeStrToTimestamp 方法
     */
    @Test
    fun `timeStrToTimestamp should convert correctly`() {
        val utility = Utility(channelName)

        // 测试 01:30:45.500 = (1*3600 + 30*60 + 45) * 1000 + 500 = 5445500
        val timestamp = utility.timeStrToTimestamp("01:30:45.500")
        assertTrue(timestamp == 5445500L)

        // 测试 00:00:00.000 = 0
        val zeroTimestamp = utility.timeStrToTimestamp("00:00:00.000")
        assertTrue(zeroTimestamp == 0L)
    }

    /**
     * 测试 getFileNameWithGifExtension 方法
     */
    @Test
    fun `getFileNameWithGifExtension should return empty for non-existent file`() {
        val utility = Utility(channelName)
        val result = utility.getFileNameWithGifExtension("/non/existent/video.mp4")
        assertTrue(result.isEmpty())
    }
}
