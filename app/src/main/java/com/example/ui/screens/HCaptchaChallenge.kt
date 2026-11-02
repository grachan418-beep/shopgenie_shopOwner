package com.example.ui.screens

import androidx.compose.runtime.Composable
import com.example.BuildConfig
import com.hcaptcha.sdk.HCaptchaCompose
import com.hcaptcha.sdk.HCaptchaConfig
import com.hcaptcha.sdk.HCaptchaResponse

@Composable
fun HCaptchaChallenge(
    open: Boolean,
    onToken: (String) -> Unit,
    onFailure: () -> Unit
) {
    if (!open) return
    if (BuildConfig.HCAPTCHA_SITE_KEY.isBlank() ||
        BuildConfig.HCAPTCHA_SITE_KEY.startsWith("YOUR_")
    ) return

    HCaptchaCompose(
        config = HCaptchaConfig.builder()
            .siteKey(BuildConfig.HCAPTCHA_SITE_KEY)
            .build()
    ) { result ->
        when (result) {
            is HCaptchaResponse.Success -> onToken(result.token)
            is HCaptchaResponse.Failure -> onFailure()
            is HCaptchaResponse.Event -> Unit
        }
    }
}
