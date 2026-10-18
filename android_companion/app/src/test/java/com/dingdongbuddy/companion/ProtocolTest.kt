package com.dingdongbuddy.companion

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Cross-implementation vectors were produced by the PWA's own
 * docs/app/app-codecs.js (WebCrypto), so these tests pin wire compatibility.
 */
class ProtocolTest {
    private val secret = "q2v9Jx0rTzM8bW1kLs7nPf4aYc6eHd3uGi5oRj2lKwE"
    private val pwaEnvelope =
        "0e93Tv4XtS2Q3Xbpoa6ztZLvNKQg18Up8WFPN0DauFzGe67pNiNTFl1SHPtomVcgvGbOVLlEBM38GSNenKmLuJS15Vbun6etd0d5hciRbWoVWCLvEAa3rCdCLMs8GPdU5bjb-gBDJ234NNd69ti7adZt7zKp0MHkR6Lkvy_K4nhX_ujzp8adDRSYP9f9wy0J"
    private val pairFragment =
        "eyJ2ZXJzaW9uIjoxLCJyb29tIjoiQWJDZEVmR2hJaktsTW5PcFFyU3RVdiIsInNlY3JldCI6InEydjlKeDByVHpNOGJXMWtMczduUGY0YVljNmVIZDN1R2k1b1JqMmxLd0UiLCJyZWxheSI6Imh0dHBzOi8vZGluZ2RvbmcueG4tLW04dHh1LmNvbSIsImhvc3RJZCI6Imhvc3QtMSIsImhvc3ROYW1lIjoi5bel5L2c55S16ISRIn0"

    @Test
    fun opensEnvelopeSealedByThePwa() {
        val message = EnvelopeCrypto(secret).open(pwaEnvelope)
        assertEquals("agent.completed", message.getString("type"))
        assertEquals("vec-1", message.getString("id"))
        assertEquals("Agent 需要你处理", message.getString("title"))
    }

    @Test
    fun derivesTheSamePushTokenAsThePwa() {
        assertEquals("vQN1UlHspbqPODwcWaqv8I-4znZzD9yRPkPACe7YEKo", EnvelopeCrypto(secret).pushToken())
    }

    @Test
    fun sealedEnvelopeRoundTrips() {
        val crypto = EnvelopeCrypto(secret)
        val sealed = crypto.seal(JSONObject().put("type", "hello").put("name", "小米"))
        assertEquals("小米", crypto.open(sealed).getString("name"))
    }

    @Test
    fun parsesTheDesktopPairingLink() {
        val pairing = Pairing.fromLinkText("https://dingdong.xn--m8txu.com/app/#pair=$pairFragment")
        assertNotNull(pairing)
        assertEquals("AbCdEfGhIjKlMnOpQrStUv", pairing!!.room)
        assertEquals("工作电脑", pairing.hostName)
        assertEquals("https://dingdong.xn--m8txu.com", pairing.relay)
    }

    @Test
    fun rejectsDamagedPairingLinks() {
        assertNull(Pairing.fromLinkText("https://dingdong.xn--m8txu.com/app/"))
        assertNull(Pairing.fromLinkText("#pair=bm90LWpzb24"))
        val shortSecret = JSONObject(String(Base64Url.decode(pairFragment), Charsets.UTF_8))
            .put("secret", "too-short")
        assertNull(Pairing.fromJson(shortSecret))
        val withHash = JSONObject(String(Base64Url.decode(pairFragment), Charsets.UTF_8))
            .put("relay", "https://relay.example/#x")
        assertNull(Pairing.fromJson(withHash))
    }

    @Test
    fun attentionKindAndSilentFlagAreRespected() {
        val event = AgentEvent.parse(EnvelopeCrypto(secret).open(pwaEnvelope))!!
        assertEquals(AgentNotificationKind.ATTENTION, event.kind)
        assertTrue(event.silent)
    }

    @Test
    fun completionDefaultsMatchThePwa() {
        val event = AgentEvent.parse(
            JSONObject()
                .put("type", "agent.completed")
                .put("id", "a1")
                .put("source", "Claude Code")
                .put("task", "修复登录")
                .put("summary", "测试全部通过"),
        )!!
        assertEquals(AgentNotificationKind.COMPLETION, event.kind)
        assertFalse(event.silent)
        assertEquals("Claude Code · Agent 完成啦", event.displayTitle)
        assertEquals("修复登录：测试全部通过", event.body)
    }

    @Test
    fun needsUserAttentionFlagAloneSelectsTheAttentionChannel() {
        val event = AgentEvent.parse(
            JSONObject().put("type", "agent.completed").put("id", "a2").put("needsUserAttention", true),
        )!!
        assertEquals(AgentNotificationKind.ATTENTION, event.kind)
        assertEquals("请打开 Agent 提醒查看并继续处理。", event.body)
    }

    @Test
    fun ignoresOtherMessageTypes() {
        assertNull(AgentEvent.parse(JSONObject().put("type", "agent.state").put("id", "x")))
        assertNull(AgentEvent.parse(JSONObject().put("type", "agent.completed")))
    }
}
