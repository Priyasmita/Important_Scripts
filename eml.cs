using System;
using System.Net;
using System.Net.Mail;
using System.Text;

public class SmtpEmail : IDisposable
{
    private readonly MailMessage _message = new MailMessage();
    private bool _disposed;

    public SmtpEmail()
    {
        _message.SubjectEncoding = Encoding.UTF8;
        _message.BodyEncoding    = Encoding.UTF8;
        _message.IsBodyHtml      = true;
        _message.Priority        = MailPriority.Normal;
    }

    // --- SMTP transport settings (leave Host null to read from app.config) ---
    public string Host { get; set; }
    public int Port { get; set; }
    public bool EnableSsl { get; set; }
    public string UserName { get; set; }
    public string Password { get; set; }
    public int Timeout { get; set; }

    // --- Message properties ---
    public MailMessage Message
    {
        get { return _message; }
    }

    public string Subject
    {
        get { return _message.Subject; }
        set { _message.Subject = value ?? string.Empty; }
    }

    public string Body
    {
        get { return _message.Body; }
        set { _message.Body = value ?? string.Empty; }
    }

    public bool IsHtml
    {
        get { return _message.IsBodyHtml; }
        set { _message.IsBodyHtml = value; }
    }

    public MailPriority Priority
    {
        get { return _message.Priority; }
        set { _message.Priority = value; }
    }

    public SmtpEmail SetFrom(string address, string displayName)
    {
        _message.From = new MailAddress(address, displayName, Encoding.UTF8);
        return this;
    }

    public SmtpEmail AddTo(string addresses)
    {
        AddRange(_message.To, addresses);
        return this;
    }

    public SmtpEmail AddCc(string addresses)
    {
        AddRange(_message.CC, addresses);
        return this;
    }

    public SmtpEmail AddBcc(string addresses)
    {
        AddRange(_message.Bcc, addresses);
        return this;
    }

    public SmtpEmail AddReplyTo(string address)
    {
        _message.ReplyToList.Add(new MailAddress(address));
        return this;
    }

    public SmtpEmail Attach(string filePath)
    {
        _message.Attachments.Add(new Attachment(filePath));
        return this;
    }

    // --- Send ---
    public void Send()
    {
        if (_message.To.Count == 0 && _message.CC.Count == 0 && _message.Bcc.Count == 0)
            throw new InvalidOperationException("No recipients have been added.");

        using (SmtpClient client = CreateClient())
        {
            client.Send(_message);
        }
    }

    private SmtpClient CreateClient()
    {
        // No Host set => picks up <system.net><mailSettings> from app.config
        SmtpClient client = string.IsNullOrEmpty(Host)
            ? new SmtpClient()
            : new SmtpClient(Host, Port == 0 ? 587 : Port);

        client.DeliveryMethod = SmtpDeliveryMethod.Network;

        if (!string.IsNullOrEmpty(Host))
            client.EnableSsl = EnableSsl;

        if (!string.IsNullOrEmpty(UserName))
        {
            client.UseDefaultCredentials = false;   // must precede Credentials
            client.Credentials = new NetworkCredential(UserName, Password);
        }

        if (Timeout > 0)
            client.Timeout = Timeout;

        return client;
    }

    private static void AddRange(MailAddressCollection collection, string addresses)
    {
        if (string.IsNullOrEmpty(addresses))
            return;

        string[] parts = addresses.Split(
            new[] { ';', ',' }, StringSplitOptions.RemoveEmptyEntries);

        foreach (string part in parts)
        {
            string trimmed = part.Trim();
            if (trimmed.Length > 0)
                collection.Add(new MailAddress(trimmed));
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _message.Dispose();     // also disposes attachments
        _disposed = true;
        GC.SuppressFinalize(this);
    }
}
