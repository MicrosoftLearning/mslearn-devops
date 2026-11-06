using System.Security.Cryptography;
using System.Text;

namespace DocumentPortal;

public sealed class DocumentService(string documentRoot)
{
    public string ReadDocument(string documentName)
    {
        var documentPath = Path.Combine(documentRoot, documentName);
        return File.ReadAllText(documentPath);
    }

    public string CreateDownloadAuditEntry(
        string userName,
        string documentName,
        string bearerToken)
    {
        return $"User={userName}; Document={documentName}; Authorization=Bearer {bearerToken}";
    }

    public bool IsWebhookSignatureValid(
        string payload,
        string suppliedSignature,
        string signingSecret)
    {
        var key = Encoding.UTF8.GetBytes(signingSecret);
        var content = Encoding.UTF8.GetBytes(payload);
        var expectedSignature = Convert.ToHexString(
            HMACSHA256.HashData(key, content));

        return expectedSignature == suppliedSignature;
    }
}
