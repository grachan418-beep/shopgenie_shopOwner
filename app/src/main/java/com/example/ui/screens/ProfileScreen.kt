package com.example.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.api.NetworkClient
import com.example.data.models.UserDto
import com.example.ui.cart.CartManager
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(
    networkClient: NetworkClient,
    onNavigateBack: () -> Unit,
    onLogout: () -> Unit
) {
    var user by remember { mutableStateOf<UserDto?>(null) }
    var serverUrl by remember { mutableStateOf(networkClient.baseUrl) }
    var esp32Url by remember { mutableStateOf(networkClient.esp32Url) }
    var isSavingSettings by remember { mutableStateOf(false) }
    var saveSuccessMessage by remember { mutableStateOf<String?>(null) }

    val coroutineScope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        try {
            val res = networkClient.apiService.getCurrentUser()
            if (res.isSuccessful && res.body() != null) {
                user = res.body()
            }
        } catch (e: Exception) {
            // User endpoint fallback
        }
    }

    fun saveConfig() {
        isSavingSettings = true
        networkClient.baseUrl = serverUrl
        networkClient.esp32Url = esp32Url
        isSavingSettings = false
        saveSuccessMessage = "Endpoint configuration saved!"
    }

    fun performLogout() {
        networkClient.clearSession()
        CartManager.clear()
        onLogout()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Shopkeeper Profile & Setup", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // User & Store Identity Card
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
            ) {
                Column(modifier = Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Default.Store,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(32.dp)
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(
                                text = user?.shopName ?: (networkClient.currentShopName ?: "My Kirana Store"),
                                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold)
                            )
                            Text(
                                text = "Username: @${user?.username ?: networkClient.currentUsername}",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }

                    if (user?.email != null) {
                        Text(
                            text = "Email: ${user?.email}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            // Hardware & Server Config
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
            ) {
                Column(modifier = Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("Connected Hardware & Endpoints", fontWeight = FontWeight.Bold)

                    if (saveSuccessMessage != null) {
                        Text(
                            text = saveSuccessMessage!!,
                            color = Color(0xFF16A34A),
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 12.sp
                        )
                    }

                    OutlinedTextField(
                        value = serverUrl,
                        onValueChange = {
                            serverUrl = it
                            saveSuccessMessage = null
                        },
                        label = { Text("Django API Base URL") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        leadingIcon = { Icon(Icons.Default.Cloud, contentDescription = null) }
                    )

                    OutlinedTextField(
                        value = esp32Url,
                        onValueChange = {
                            esp32Url = it
                            saveSuccessMessage = null
                        },
                        label = { Text("ESP32-CAM MJPEG Stream URL") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        leadingIcon = { Icon(Icons.Default.Videocam, contentDescription = null) }
                    )

                    Button(
                        onClick = { saveConfig() },
                        modifier = Modifier.align(Alignment.End),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text("Save Configuration")
                    }
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            // Logout Button
            Button(
                onClick = { performLogout() },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
            ) {
                Icon(Icons.Default.Logout, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("Logout from Shop", fontWeight = FontWeight.Bold)
            }
        }
    }
}
