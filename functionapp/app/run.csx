#r "Newtonsoft.Json"

using System.Net;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Primitives;
using Newtonsoft.Json;

public class OutTable
{
    public string PartitionKey { get; set; }
    public string RowKey { get; set; }
    public string Name { get; set; }
}

public static async Task<IActionResult> Run(HttpRequest req, ICollector<OutTable> outputTable, ILogger log)
{
    log.LogInformation("C# HTTP trigger function processed a request.");

    outputTable.Add(new OutTable() { PartitionKey = "Http", RowKey = Guid.NewGuid().ToString(), Name = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff") });

    string responseMessage = "This HTTP triggered function executed successfully.";
    return new OkObjectResult(responseMessage);
}
