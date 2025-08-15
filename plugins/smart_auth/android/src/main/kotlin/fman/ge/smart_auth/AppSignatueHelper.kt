package fman.ge.smart_auth

import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import android.util.Base64
import java.security.MessageDigest
import java.security.NoSuchAlgorithmException

class AppSignatureHelper(private val context: Context) {

    fun getAppSignatures(): List<String> {
        val appCodes = ArrayList<String>()

        try {
            val packageName = context.packageName
            val packageManager = context.packageManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val signingInfo = packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                ).signingInfo

                val signatures: Array<Signature> = signingInfo?.apkContentsSigners ?: emptyArray()
                for (signature in signatures) {
                    val hash = hash(packageName, signature.toByteArray())
                    if (hash != null) {
                        appCodes.add(hash)
                    }
                }
            } else {
                val packageInfo = packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNATURES
                )
                val signatures: Array<Signature> = packageInfo.signatures ?: emptyArray()
                for (signature in signatures) {
                    val hash = hash(packageName, signature.toByteArray())
                    if (hash != null) {
                        appCodes.add(hash)
                    }
                }
            }

        } catch (e: Exception) {
            e.printStackTrace()
        }

        return appCodes
    }

    private fun hash(packageName: String, signature: ByteArray): String? {
        try {
            val messageDigest = MessageDigest.getInstance("SHA-256")
            messageDigest.update(signature)
            val digest = messageDigest.digest()
            val base64Hash = Base64.encodeToString(digest, Base64.NO_WRAP)
            return "$packageName $base64Hash"
        } catch (e: NoSuchAlgorithmException) {
            e.printStackTrace()
        }
        return null
    }
}
