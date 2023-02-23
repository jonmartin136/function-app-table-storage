using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;

namespace functionapp
{
    public class OutTable
    {
        public string PartitionKey { get; set; }
        public string RowKey { get; set; }
        public string Name { get; set; }
    }
    public static class app
    {
        [FunctionName("app")]
        public static async Task<IActionResult> Run([HttpTrigger(AuthorizationLevel.Anonymous, "get", "post", Route = null)] HttpRequest req, ICollector<OutTable> outputTable, ILogger log)
        {
            log.LogInformation("C# HTTP trigger function processed a request.");

            outputTable.Add(new OutTable() { PartitionKey = "Http", RowKey = Guid.NewGuid().ToString(), Name = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff") });

            string responseMessage = "This HTTP triggered function executed successfully.";
            return new OkObjectResult(responseMessage);
        }
    }
}
