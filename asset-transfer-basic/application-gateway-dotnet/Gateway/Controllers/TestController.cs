using Gateway.Bussiness;
using HyperledgerSdk;
using Microsoft.AspNetCore.Mvc;

namespace Gateway.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class TestController : ControllerBase
    {
        private readonly ILogger<TestController> _logger;

        public TestController(ILogger<TestController> logger)
        {
            _logger = logger;
        }

        [HttpPost]
        public async Task<HFTransactionResponse> Post(string fromId, string toId, decimal amount)
        {
            return await HyperledgerBusiness.Transfer("", fromId, toId, amount);
        }
    }
}
