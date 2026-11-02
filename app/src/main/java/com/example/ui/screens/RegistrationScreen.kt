package com.example.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.example.BuildConfig
import com.example.data.api.NetworkClient
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RegistrationScreen(
    networkClient: NetworkClient,
    onNavigateBackToLogin: () -> Unit
) {
    var username by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var shopName by remember { mutableStateOf("") }
    var phoneNumber by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var verificationCode by remember { mutableStateOf("") }
    var captchaToken by remember { mutableStateOf("") }
    var captchaOpen by remember { mutableStateOf(false) }
    var verificationPending by remember { mutableStateOf(false) }
    var emailVerified by remember { mutableStateOf(false) }

    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val coroutineScope = rememberCoroutineScope()
    val focusManager = LocalFocusManager.current

    fun performRegister() {
        if (verificationPending || emailVerified) return
        if (username.isBlank() || email.isBlank() || shopName.isBlank() || password.isBlank()) {
            errorMessage = "Please fill in all required fields."
            return
        }
        if (password.length < 10) {
            errorMessage = "Password must be at least 10 characters."
            return
        }
        if (password != confirmPassword) {
            errorMessage = "Passwords do not match."
            return
        }
        if (captchaToken.isBlank()) {
            if (BuildConfig.HCAPTCHA_SITE_KEY.isBlank() ||
                BuildConfig.HCAPTCHA_SITE_KEY.startsWith("YOUR_")
            ) {
                errorMessage = "Registration verification is not configured. Please contact support."
            } else {
                captchaOpen = true
                errorMessage = "Complete the CAPTCHA, then tap Register & Start again."
            }
            return
        }

        isLoading = true
        errorMessage = null

        coroutineScope.launch {
            try {
                val payload = mutableMapOf(
                    "username" to username.trim(),
                    "email" to email.trim(),
                    "password" to password,
                    "password_confirm" to confirmPassword,
                    "shop_name" to shopName.trim(),
                    "captcha_token" to captchaToken
                )
                if (phoneNumber.isNotBlank()) {
                    payload["phone_number"] = phoneNumber.trim()
                }

                val response = networkClient.apiService.register(payload)
                captchaToken = ""

                if (response.isSuccessful) {
                    verificationPending = true
                    errorMessage = response.body()?.detail
                        ?: "If registration can be completed, check your inbox for a verification code."
                } else {
                    errorMessage = "Registration could not be completed. Check your information and try again."
                }
                isLoading = false
            } catch (e: Exception) {
                isLoading = false
                captchaToken = ""
                errorMessage = "Registration could not be completed. Please check your connection and try again."
            }
        }
    }

    fun performEmailVerification() {
        if (verificationCode.length != 6) {
            errorMessage = "Enter the 6-digit code from your email."
            return
        }
        isLoading = true
        errorMessage = null
        coroutineScope.launch {
            try {
                val response = networkClient.apiService.verifyEmail(
                    mapOf("email" to email.trim(), "code" to verificationCode.trim())
                )
                if (response.isSuccessful) {
                    emailVerified = true
                    errorMessage = "Email verified. You can now sign in."
                } else {
                    errorMessage = "The verification code is invalid or expired."
                }
            } catch (e: Exception) {
                errorMessage = "Email verification could not be completed. Please try again."
            } finally {
                isLoading = false
            }
        }
    }

    fun resendVerification() {
        if (captchaToken.isBlank()) {
            if (BuildConfig.HCAPTCHA_SITE_KEY.isBlank() ||
                BuildConfig.HCAPTCHA_SITE_KEY.startsWith("YOUR_")
            ) {
                errorMessage = "Registration verification is not configured. Please contact support."
            } else {
                captchaOpen = true
                errorMessage = "Complete the CAPTCHA, then tap Resend code again."
            }
            return
        }
        isLoading = true
        errorMessage = null
        coroutineScope.launch {
            try {
                networkClient.apiService.resendVerification(
                    mapOf("email" to email.trim(), "captcha_token" to captchaToken)
                )
                captchaToken = ""
                errorMessage = "If the account is eligible, a verification code will be sent."
            } catch (e: Exception) {
                captchaToken = ""
                errorMessage = "The request could not be completed. Please try again later."
            } finally {
                isLoading = false
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Register New Store", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBackToLogin) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back to login")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 24.dp)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = "Join ShopGenie Multi-Tenant Retail",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Spacer(modifier = Modifier.height(20.dp))

            if (errorMessage != null) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)
                ) {
                    Text(
                        text = errorMessage!!,
                        color = MaterialTheme.colorScheme.onErrorContainer,
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.padding(12.dp)
                    )
                }
                Spacer(modifier = Modifier.height(16.dp))
            }

            OutlinedTextField(
                value = shopName,
                onValueChange = { shopName = it },
                label = { Text("Store / Shop Name *") },
                leadingIcon = { Icon(Icons.Default.Store, contentDescription = null) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next),
                keyboardActions = KeyboardActions(onNext = { focusManager.moveFocus(FocusDirection.Down) })
            )

            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = username,
                onValueChange = { username = it },
                label = { Text("Username *") },
                leadingIcon = { Icon(Icons.Default.Person, contentDescription = null) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next),
                keyboardActions = KeyboardActions(onNext = { focusManager.moveFocus(FocusDirection.Down) })
            )

            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text("Email Address *") },
                leadingIcon = { Icon(Icons.Default.Email, contentDescription = null) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next),
                keyboardActions = KeyboardActions(onNext = { focusManager.moveFocus(FocusDirection.Down) })
            )

            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = phoneNumber,
                onValueChange = { phoneNumber = it },
                label = { Text("Phone Number (Optional)") },
                leadingIcon = { Icon(Icons.Default.Phone, contentDescription = null) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone, imeAction = ImeAction.Next),
                keyboardActions = KeyboardActions(onNext = { focusManager.moveFocus(FocusDirection.Down) })
            )

            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text("Password (min 10 chars) *") },
                leadingIcon = { Icon(Icons.Default.Lock, contentDescription = null) },
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Next),
                keyboardActions = KeyboardActions(onNext = { focusManager.moveFocus(FocusDirection.Down) })
            )

            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = confirmPassword,
                onValueChange = { confirmPassword = it },
                label = { Text("Confirm Password *") },
                leadingIcon = { Icon(Icons.Default.CheckCircle, contentDescription = null) },
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = {
                    focusManager.clearFocus()
                    performRegister()
                })
            )

            if (verificationPending && !emailVerified) {
                Text(
                    text = "Enter the verification code sent to your email address.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(12.dp))
                OutlinedTextField(
                    value = verificationCode,
                    onValueChange = { verificationCode = it.filter(Char::isDigit).take(6) },
                    label = { Text("6-digit verification code") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
                )
                Spacer(modifier = Modifier.height(12.dp))
                Button(
                    onClick = { performEmailVerification() },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !isLoading
                ) {
                    Text("Verify email")
                }
                TextButton(
                    onClick = { resendVerification() },
                    enabled = !isLoading
                ) {
                    Text("Resend code")
                }
            }
            if (emailVerified) {
                TextButton(onClick = onNavigateBackToLogin) {
                    Text("Go to sign in")
                }
            }

            if (!verificationPending && !emailVerified) {
                Button(
                    onClick = { performRegister() },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp),
                    shape = RoundedCornerShape(12.dp),
                    enabled = !isLoading,
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                ) {
                    if (isLoading) {
                        CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
                    } else {
                        Text("Register & Verify Email", fontWeight = FontWeight.Bold)
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))
        }
    }
    HCaptchaChallenge(
        open = captchaOpen,
        onToken = {
            captchaToken = it
            captchaOpen = false
            errorMessage = null
        },
        onFailure = {
            captchaOpen = false
            errorMessage = "CAPTCHA verification failed. Please try again."
        }
    )
}
