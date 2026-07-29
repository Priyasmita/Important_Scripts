using System;
using System.Net;
using System.Text;

public static class StatsTableBuilder
{
    public static string Build(string firstStats, string secondStats)
    {
        bool isMatch = string.Equals(
            (firstStats ?? string.Empty).Trim(),
            (secondStats ?? string.Empty).Trim(),
            StringComparison.OrdinalIgnoreCase);

        string answer   = isMatch ? "Yes" : "No";
        string answerBg = isMatch ? "#008000" : "#CC0000";

        const string label  = "padding:10px 14px; border:1px solid #999999; "
                            + "background-color:#000000; color:#FFFFFF; font-weight:bold;";
        const string value  = "padding:10px 14px; border:1px solid #999999; "
                            + "background-color:#FFFFFF; color:#000000;";

        string result = string.Format(
            "padding:10px 14px; border:1px solid #999999; "
          + "background-color:{0}; color:#FFFFFF; font-weight:bold;", answerBg);

        var sb = new StringBuilder();
        sb.Append("<html><body style=\"margin:0;padding:0;\">");
        sb.Append("<table cellpadding=\"0\" cellspacing=\"0\" border=\"0\" ")
          .Append("style=\"border-collapse:collapse; font-family:Arial,Helvetica,sans-serif; font-size:14px;\">");

        sb.Append("<tr>")
          .AppendFormat("<td bgcolor=\"#000000\" style=\"{0}\">FIRST_STATS</td>", label)
          .AppendFormat("<td bgcolor=\"#FFFFFF\" style=\"{0}\">{1}</td>", value, Enc(firstStats))
          .Append("</tr>");

        sb.Append("<tr>")
          .AppendFormat("<td bgcolor=\"#000000\" style=\"{0}\">SECOND_STATS</td>", label)
          .AppendFormat("<td bgcolor=\"#FFFFFF\" style=\"{0}\">{1}</td>", value, Enc(secondStats))
          .Append("</tr>");

        sb.Append("<tr>")
          .AppendFormat("<td bgcolor=\"#FFFFFF\" style=\"{0}\">Do stats match ?</td>", value)
          .AppendFormat("<td bgcolor=\"{0}\" style=\"{1}\">{2}</td>", answerBg, result, answer)
          .Append("</tr>");

        sb.Append("</table></body></html>");
        return sb.ToString();
    }

    private static string Enc(string s)
    {
        return WebUtility.HtmlEncode(s ?? string.Empty);
    }
}
