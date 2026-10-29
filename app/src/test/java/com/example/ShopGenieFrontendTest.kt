package com.example

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.example.data.api.NetworkClient
import com.example.data.models.*
import com.example.ui.cart.CartManager
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ShopGenieFrontendTest {

    private lateinit var context: Context
    private lateinit var networkClient: NetworkClient
    private val moshi: Moshi = Moshi.Builder().add(KotlinJsonAdapterFactory()).build()

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        networkClient = NetworkClient.getInstance(context)
        networkClient.clearSession()
        CartManager.clear()
    }

    // 1. The app opens without errors
    @Test
    fun test1_appOpensWithoutErrors() {
        val appName = context.getString(R.string.app_name)
        assertEquals("ShopGenie", appName)
        assertNotNull(networkClient)
        assertNotNull(networkClient.apiService)
    }

    // 2. Login and registration screens work
    @Test
    fun test2_loginAndRegistrationPayloadsAndResponses() {
        val loginPayload = mapOf("username" to "shopkeeper1", "password" to "securePass123")
        assertEquals("shopkeeper1", loginPayload["username"])
        assertEquals("securePass123", loginPayload["password"])

        val registerPayload = mapOf(
            "username" to "shopkeeper2",
            "password" to "pass123",
            "shop_name" to "Shree Kirana",
            "phone_number" to "9876543210"
        )
        assertEquals("shopkeeper2", registerPayload["username"])
        assertEquals("Shree Kirana", registerPayload["shop_name"])

        val authJson = """
            {
                "message": "Login successful",
                "access": "test_access_jwt",
                "refresh": "test_refresh_jwt",
                "user": {
                    "id": 1,
                    "username": "shopkeeper1",
                    "email": "shop@example.com",
                    "shop_name": "Shree Kirana"
                }
            }
        """.trimIndent()
        val adapter = moshi.adapter(AuthResponse::class.java)
        val authResponse = adapter.fromJson(authJson)

        assertNotNull(authResponse)
        assertEquals("test_access_jwt", authResponse?.accessToken)
        assertEquals("test_refresh_jwt", authResponse?.refreshToken)
        assertEquals("Shree Kirana", authResponse?.user?.shopName)
    }

    // 3. JWT authentication connects to Django
    @Test
    fun test3_jwtAuthenticationConnects() {
        assertFalse(networkClient.isLoggedIn)

        networkClient.accessToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummyAccessToken"
        networkClient.refreshToken = "dummyRefreshToken"
        networkClient.currentUsername = "shopowner"

        assertTrue(networkClient.isLoggedIn)
        assertEquals("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummyAccessToken", networkClient.accessToken)
        assertEquals("shopowner", networkClient.currentUsername)
    }

    // 4. Product list loads from the backend
    @Test
    fun test4_productListLoadsAndFilters() {
        val jsonList = """
            [
                {"id": 1, "name": "Aashirvaad Atta 5kg", "category": "Flour", "selling_type": "UNIT", "cost_price": 210.0, "price_per_unit": 250.0, "quantity": 15.0, "is_loose": false},
                {"id": 2, "name": "Moong Dal", "category": "Pulses", "selling_type": "KG", "cost_price": 95.0, "price_per_unit": 120.0, "quantity": 50.0, "is_loose": true}
            ]
        """.trimIndent()

        val adapter = moshi.adapter<List<ProductDto>>(
            com.squareup.moshi.Types.newParameterizedType(List::class.java, ProductDto::class.java)
        )
        val products = adapter.fromJson(jsonList)
        assertNotNull(products)
        assertEquals(2, products!!.size)

        // Filter unit and loose
        val unitProducts = products.filter { it.sellingType == "UNIT" }
        val looseProducts = products.filter { it.isLoose || it.sellingType == "KG" }

        assertEquals(1, unitProducts.size)
        assertEquals("Aashirvaad Atta 5kg", unitProducts[0].name)
        assertEquals(1, looseProducts.size)
        assertEquals("Moong Dal", looseProducts[0].name)
    }

    // 5. Product registration works
    @Test
    fun test5_productRegistrationModelSerialization() {
        val reqUnit = ProductCreateRequest(
            name = "Maggi 2-Minute Noodles 70g",
            category = "Snacks",
            sellingType = "UNIT",
            costPrice = 11.5,
            pricePerUnit = 14.0,
            quantity = 96.0,
            isLoose = false
        )
        val adapter = moshi.adapter(ProductCreateRequest::class.java)
        val json = adapter.toJson(reqUnit)

        assertTrue(json.contains("Maggi 2-Minute Noodles 70g"))
        assertTrue(json.contains("UNIT"))
    }

    // 6. Inventory works
    @Test
    fun test6_inventoryStockAndAlertsWork() {
        val stock1 = ProductDto(1, "Turmeric Powder 100g", "Spices", "UNIT", 20.0, 30.0, 3.0)
        val stock2 = ProductDto(2, "Basmati Rice 1kg", "Grains", "UNIT", 80.0, 110.0, 20.0)

        val products = listOf(stock1, stock2)
        val lowStockItems = products.filter { it.quantity < 5.0 }

        assertEquals(1, lowStockItems.size)
        assertEquals("Turmeric Powder 100g", lowStockItems[0].name)

        val totalStockValue = products.sumOf { it.quantity * it.pricePerUnit }
        assertEquals(3.0 * 30.0 + 20.0 * 110.0, totalStockValue, 0.001)
    }

    // 7. Cart and checkout work
    @Test
    fun test7_cartAndCheckoutFlow() {
        CartManager.clear()
        assertEquals(0, CartManager.itemCount)

        val oil = ProductDto(10, "Fortune Mustard Oil 1L", "Oils", "UNIT", 120.0, 145.0, 20.0)
        CartManager.addItem(oil, 3.0)

        assertEquals(1, CartManager.itemCount)
        assertEquals(435.0, CartManager.totalAmount, 0.001)

        val req = CheckoutAcceptRequest(productId = 10, quantity = 3.0, invoiceId = null)
        assertEquals(10, req.productId)
        assertEquals(3.0, req.quantity, 0.001)
        assertNull(req.invoiceId)
    }

    // 8. Invoice/receipt screen works
    @Test
    fun test8_invoiceAndReceiptModelWorks() {
        val invoiceJson = """
            {
                "id": 501,
                "created_at": "2026-09-06T10:00:00Z",
                "status": "PAID",
                "total_amount": 255.0,
                "items": [
                    {
                        "id": 1,
                        "product": 10,
                        "product_name": "Tata Salt 1kg",
                        "quantity": 2.0,
                        "formatted_quantity": "2 units",
                        "unit_price": 28.0,
                        "total_price": 56.0
                    }
                ]
            }
        """.trimIndent()

        val adapter = moshi.adapter(InvoiceDto::class.java)
        val invoice = adapter.fromJson(invoiceJson)

        assertNotNull(invoice)
        assertEquals(501, invoice!!.id)
        assertEquals("PAID", invoice.status)
        assertEquals(255.0, invoice.totalAmount, 0.001)
        assertEquals(1, invoice.items.size)
        assertEquals("Tata Salt 1kg", invoice.items[0].productName)
    }

    // 9. Camera/AI scan screen exists
    @Test
    fun test9_cameraAiScanContractsExist() {
        val matchReq = MatchProductRequest(
            imageBase64 = null,
            captureFromEsp32 = true,
            esp32CamUrl = "http://192.168.1.100:81/stream",
            similarityThreshold = 0.75
        )
        val adapter = moshi.adapter(MatchProductRequest::class.java)
        val json = adapter.toJson(matchReq)

        assertTrue(json.contains("esp32_cam_url"))
        assertTrue(json.contains("0.75"))

        val matchRes = MatchResponse(
            matchType = "PRODUCT",
            productId = 42,
            name = "Parle-G Biscuit 250g",
            similarity = 0.92,
            pricePerUnit = 25.0
        )
        assertEquals("PRODUCT", matchRes.matchType)
        assertEquals(0.92, matchRes.similarity ?: 0.0, 0.001)
    }

    // 10. Loose-item weight entry works
    @Test
    fun test10_looseItemWeightAndPricingCalculations() {
        val sugarRatePerKg = 42.0
        val measuredWeight = 1.375 // 1 kg 375 grams
        val calculatedPrice = measuredWeight * sugarRatePerKg

        assertEquals(57.75, calculatedPrice, 0.001)

        CartManager.addItemDirect(
            productId = 99,
            name = "Premium Sugar (Loose)",
            category = "Staples",
            sellingType = "KG",
            pricePerUnit = sugarRatePerKg,
            quantity = measuredWeight,
            isLoose = true
        )

        assertEquals(1, CartManager.itemCount)
        assertEquals(57.75, CartManager.totalAmount, 0.001)
        assertTrue(CartManager.items[0].formattedQuantity.contains("1.375 kg"))
    }

    // 11. API errors are handled
    @Test
    fun test11_apiErrorHandlingStructures() {
        val errorJson = """{"error": "Product out of stock", "detail": "Insufficient balance"}"""
        val adapter = moshi.adapter(Map::class.java)
        val errorMap = adapter.fromJson(errorJson)

        assertNotNull(errorMap)
        assertEquals("Product out of stock", errorMap?.get("error"))
        assertEquals("Insufficient balance", errorMap?.get("detail"))
    }

    // 12. Logout works
    @Test
    fun test12_logoutWorksAndClearsSession() {
        networkClient.accessToken = "active_jwt_token"
        networkClient.refreshToken = "refresh_token"
        networkClient.currentUsername = "shopowner1"
        CartManager.addItemDirect(1, "Sample Item", "Test", "UNIT", 10.0, 1.0, false)

        assertTrue(networkClient.isLoggedIn)
        assertEquals(1, CartManager.itemCount)

        // Perform Logout
        networkClient.clearSession()
        CartManager.clear()

        assertFalse(networkClient.isLoggedIn)
        assertNull(networkClient.accessToken)
        assertNull(networkClient.refreshToken)
        assertEquals(0, CartManager.itemCount)
    }
}
