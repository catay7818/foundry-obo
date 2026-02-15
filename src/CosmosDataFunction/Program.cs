using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using CosmosDataFunction.Services;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureServices(services =>
    {
        services.AddSingleton<ITokenValidationService, TokenValidationService>();
        services.AddSingleton<IOboTokenProvider, OboTokenProvider>();
        services.AddSingleton<ICosmosDbService, CosmosDbService>();
    })
    .Build();

host.Run();
