package com.example.ui.screens

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.api.NetworkClient
import com.example.data.models.MatchProductRequest
import com.example.data.models.MatchResponse
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CameraScanScreen(
    networkClient: NetworkClient,
    onNavigateBack: () -> Unit,
    onMatchFound: (match: MatchResponse) -> Unit,
    onNavigateLooseSelection: () -> Unit
) {
    var esp32Url by remember { mutableStateOf(networkClient.esp32Url) }
    var isScanning by remember { mutableStateOf(false) }
    var lastCapturedBitmap by remember { mutableStateOf<Bitmap?>(null) }
    var statusMessage by remember { mutableStateOf("ESP32-CAM optical sensor ready") }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var showSettingsDialog by remember { mutableStateOf(false) }

    val coroutineScope = rememberCoroutineScope()

    fun triggerAiScan() {
        isScanning = true
        errorMessage = null
        statusMessage = "Capturing frame from ESP32-CAM stream..."

        coroutineScope.launch {
            try {
                networkClient.esp32Url = esp32Url

                // Step 1: Capture frame and embed from ESP32-CAM endpoint via backend vision proxy
                val capturePayload = mapOf("esp32_url" to esp32Url)
                val captureRes = networkClient.apiService.captureFromEsp32(capturePayload)

                if (captureRes.isSuccessful && captureRes.body() != null) {
                    val capBody = captureRes.body()!!
                    val base64Img = capBody.imageBase64

                    // Decode preview image if available
                    if (!base64Img.isNullOrBlank()) {
                        try {
                            val decoded = Base64.decode(base64Img, Base64.DEFAULT)
                            lastCapturedBitmap = BitmapFactory.decodeByteArray(decoded, 0, decoded.size)
                        } catch (e: Exception) {
                            // Non-critical image decode fallback
                        }
                    }

                    statusMessage = "Matching visual vector with inventory database..."

                    // Step 2: Call product match API
                    val matchReq = MatchProductRequest(
                        imageBase64 = base64Img,
                        captureFromEsp32 = false,
                        similarityThreshold = 0.75
                    )
                    val matchRes = networkClient.apiService.matchProduct(matchReq)

                    if (matchRes.isSuccessful && matchRes.body() != null) {
                        val match = matchRes.body()!!
                        isScanning = false
                        statusMessage = "Classification complete!"
                        onMatchFound(match)
                    } else {
                        isScanning = false
                        val err = matchRes.errorBody()?.string() ?: ""
                        errorMessage = "Match failed: $err"
                        statusMessage = "Scanning failed"
                    }
                } else {
                    // Fallback to direct match trigger with esp32_cam_url flag
                    statusMessage = "Querying backend vision matcher directly..."
                    val matchReq = MatchProductRequest(
                        captureFromEsp32 = true,
                        esp32CamUrl = esp32Url,
                        similarityThreshold = 0.75
                    )
                    val matchRes = networkClient.apiService.matchProduct(matchReq)
                    if (matchRes.isSuccessful && matchRes.body() != null) {
                        val match = matchRes.body()!!
                        isScanning = false
                        statusMessage = "Classification complete!"
                        onMatchFound(match)
                    } else {
                        isScanning = false
                        errorMessage = "ESP32-CAM capture failed. Verify camera is powered and accessible at $esp32Url"
                        statusMessage = "Sensor stream unreachable"
                    }
                }
            } catch (e: Exception) {
                isScanning = false
                errorMessage = "Camera error: ${e.localizedMessage}"
                statusMessage = "Sensor error"
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("ESP32-CAM AI Vision", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { showSettingsDialog = true }) {
                        Icon(Icons.Default.Settings, contentDescription = "ESP32 URL Settings")
                    }
                }
            )
        }
    ) { padding ->
        if (showSettingsDialog) {
            AlertDialog(
                onDismissRequest = { showSettingsDialog = false },
                title = { Text("ESP32-CAM Stream URL") },
                text = {
                    Column {
                        Text("Enter the MJPEG stream endpoint of the external hardware camera:", fontSize = 13.sp)
                        Spacer(modifier = Modifier.height(8.dp))
                        OutlinedTextField(
                            value = esp32Url,
                            onValueChange = { esp32Url = it },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                },
                confirmButton = {
                    Button(onClick = {
                        networkClient.esp32Url = esp32Url
                        showSettingsDialog = false
                    }) {
                        Text("Save")
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showSettingsDialog = false }) {
                        Text("Cancel")
                    }
                }
            )
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Viewfinder Container
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(300.dp),
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = Color(0xFF0F172A))
            ) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    if (lastCapturedBitmap != null) {
                        Image(
                            bitmap = lastCapturedBitmap!!.asImageBitmap(),
                            contentDescription = "Captured Frame",
                            modifier = Modifier.fillMaxSize()
                        )
                    } else {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(80.dp)
                                    .clip(CircleShape)
                                    .background(Color.White.copy(alpha = 0.1f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Videocam,
                                    contentDescription = null,
                                    tint = Color.White,
                                    modifier = Modifier.size(44.dp)
                                )
                            }
                            Spacer(modifier = Modifier.height(12.dp))
                            Text(
                                text = "External ESP32 Optical Rig",
                                color = Color.White,
                                fontWeight = FontWeight.SemiBold
                            )
                            Text(
                                text = "Stream: $esp32Url",
                                color = Color.White.copy(alpha = 0.6f),
                                fontSize = 11.sp
                            )
                        }
                    }

                    // Scanner overlay reticle
                    Box(
                        modifier = Modifier
                            .size(200.dp)
                            .border(2.dp, Color(0xFFFFB951).copy(alpha = 0.6f), RoundedCornerShape(16.dp))
                    )
                }
            }

            // Status message
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = if (errorMessage != null) MaterialTheme.colorScheme.errorContainer else MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = if (errorMessage != null) Icons.Default.Error else Icons.Default.Info,
                        contentDescription = null,
                        tint = if (errorMessage != null) MaterialTheme.colorScheme.onErrorContainer else MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(
                        text = errorMessage ?: statusMessage,
                        style = MaterialTheme.typography.bodyMedium,
                        color = if (errorMessage != null) MaterialTheme.colorScheme.onErrorContainer else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            // Capture Action Button
            Button(
                onClick = { triggerAiScan() },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                shape = RoundedCornerShape(14.dp),
                enabled = !isScanning,
                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
            ) {
                if (isScanning) {
                    CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
                    Spacer(modifier = Modifier.width(12.dp))
                    Text("Analyzing MobileNetV3 Embeddings...")
                } else {
                    Icon(Icons.Default.CameraAlt, contentDescription = null)
                    Spacer(modifier = Modifier.width(10.dp))
                    Text("Trigger ESP32 Optical Scan", fontWeight = FontWeight.Bold)
                }
            }

            // Manual Loose Item Prompt
            OutlinedButton(
                onClick = onNavigateLooseSelection,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
                shape = RoundedCornerShape(12.dp)
            ) {
                Icon(Icons.Default.Scale, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("Select Plain Bag / Loose Commodity Manually")
            }
        }
    }
}
