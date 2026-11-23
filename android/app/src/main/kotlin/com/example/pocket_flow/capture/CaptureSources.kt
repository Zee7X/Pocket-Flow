package com.example.pocket_flow.capture

/**
 * Daftar bawaan aplikasi yang notifikasinya dibaca. Harus sama dengan
 * lib/features/wallets/domain/payment_providers.dart. Flutter mengirim daftar
 * terbaru (sesuai pengaturan pengguna) lewat setAllowedPackages.
 */
object CaptureSources {
    val DEFAULT_PACKAGES: Set<String> = setOf(
        // E-wallet
        "com.gojek.gopay", "com.gojek.app", "ovo.id", "id.dana", "com.shopee.id",
        "com.telkom.mwallet", "com.grabtaxi.passenger", "id.flip",
        // Bank
        "com.bca", "com.bca.mybca.omni.android", "com.bcadigital.blu", "id.co.bri.brimo",
        "id.bmri.livin", "src.com.bni", "id.bni.wondr", "com.bsm.activity2",
        "com.jago.digitalBanking", "id.co.bankbkemobile.digitalbank", "com.btpn.dc",
        "id.co.cimbniaga.mobile.android",
        // Paylater / marketplace
        "com.tokopedia.tkpd", "com.finaccel.android",
    )

    /** Pra-filter murah: hanya simpan teks yang menyebut nominal rupiah. */
    private val AMOUNT = Regex("""(?i)(rp\.?|idr)\s*\d""")

    fun looksLikeTransaction(text: String): Boolean = AMOUNT.containsMatchIn(text)
}
