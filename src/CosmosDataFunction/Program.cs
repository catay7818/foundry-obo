using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using CosmosDataFunction.Services;

var host = new HostBuilder()
    .ConfigureFunctionsWebApplication()
    .ConfigureServices(services =>
    {
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();
        services.AddSingleton<ITokenValidationService, TokenValidationService>();
        services.AddSingleton<IOboTokenProvider, OboTokenProvider>();
        services.AddSingleton<ICosmosDbService, CosmosDbService>();
    })
    .Build();

host.Run();
