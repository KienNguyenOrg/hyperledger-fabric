using Gateway.Bussiness;
using HyperledgerSdk;
using Microsoft.AspNetCore.Mvc;

namespace Gateway.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class Test1Controller : ControllerBase
    {
        private readonly ILogger<Test1Controller> _logger;

        public Test1Controller(ILogger<Test1Controller> logger)
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
