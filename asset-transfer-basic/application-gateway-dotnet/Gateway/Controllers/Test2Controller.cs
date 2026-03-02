using Gateway.Bussiness;
using HyperledgerSdk;
using Microsoft.AspNetCore.Mvc;

namespace Gateway.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class Test2Controller : ControllerBase
    {
        private readonly ILogger<Test2Controller> _logger;

        public Test2Controller(ILogger<Test2Controller> logger)
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
