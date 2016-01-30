---
date : "2016-01-30"
title : "Using IdentityServer 4 with ServiceStack and Angular"
comments: true
categories: [Angluar ServiceStack]
tags: [test]
keywords: "Angular, ServiceStack, Identity Server 4,Open Id Connect,AuthProvider" 
---

We've looking to use a custom OAuth/OpenID provider for a few of our projects and after reviewing the options available we decided to use Identity Server as it looked to be the most stable and feature rich.  Currently we use ServiceStack for our backend and while ServiceStack has build in support for OAuth and OpenID it doesn't appear to have any support for OpenId Connect.  And while we will be using OAuth tokens we will be using the OpenId Connect configuration endpoints for configuration.

<!--more-->

# Step 1: Setup Identity Server
I'm not going to go into too much detail here as there are plenty of good tutorials and blog posts on how to setup identity server already.  We chose to go with Identity Server 4 as it runs on asp.net core.

Here is the code I used to configure Identity Server:
{{< highlight csharp >}}

    public void ConfigureServices(IServiceCollection services)
        {
            //TODO: This is the demo cert, replace with our own
            var cert = new X509Certificate2(Path.Combine(_environment.ApplicationBasePath, "idsrv4test.pfx"), "idsrv3test");

            var builder = services.AddIdentityServer(options =>
            {
                options.SigningCertificate = cert;
                options.SiteName = "Punchcard Identity Server (STS)";
            });

            builder.AddInMemoryClients(Clients.Get());
            builder.AddInMemoryScopes(Scopes.Get());
            builder.AddInMemoryUsers(Users.Get());
            builder.AddCustomGrantValidator<CustomGrantValidator>();

            // for the UI
            services
                .AddMvc()
                .AddRazorOptions(razor =>
                {
                    razor.ViewLocationExpanders.Add(new IdSvrHost.UI.CustomViewLocationExpander());
                });
            services.AddTransient<IdSvrHost.UI.Login.LoginService>();
        }

        public void Configure(IApplicationBuilder app, ILoggerFactory loggerFactory)
        {
            loggerFactory.AddConsole(LogLevel.Verbose);
            loggerFactory.AddDebug(LogLevel.Verbose);
            // For Test only change in prod
            app.UseCors(builder =>
                            builder.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod().AllowCredentials()); 
            app.UseDeveloperExceptionPage();
            app.UseIISPlatformHandler();
            app.UseIdentityServer();
            app.UseStaticFiles();
            app.UseMvcWithDefaultRoute();
        }
{{< /highlight>}}

And the client configuration for identity server:
{{< highlight csharp >}}

    ///////////////////////////////////////////
    // JS OIDC Sample
    //////////////////////////////////////////
    new Client
    {
        ClientId = "js_oidc",
        ClientName = "JavaScript OIDC Client",
        ClientUri = "http://identityserver.io",

        Flow = Flows.Implicit,
        RedirectUris = new List<string>
        {
            "http://localhost:7017/index.html",
            "http://localhost:7017/silent_renew.html",

            "http://localhost:7200/callback.html"
        },
        PostLogoutRedirectUris = new List<string>
        {
            "http://localhost:7017/index.html",
        },

        AllowedCorsOrigins = new List<string>
        {
            "http://localhost:7017","*"
        },

        AllowedScopes = new List<string>
        {
            StandardScopes.OpenId.Name,
            StandardScopes.Profile.Name,
            StandardScopes.Email.Name,
            StandardScopes.Roles.Name,
            "api1", "api2"
        }
    }
{{< /highlight>}}


# Step 2: Create a custom authprovider for ServiceStack

Next we created a custom Authentication Provider for Service Stack.  We plan on using the code in several different project so we'd like the amount of configuration neccessary to use the provider to be minimal.  Luckily OpenID Connect provieds a discovery endpoint that can be used to retrieve the configuration from the server (including the public certificate).

The goald is only have to provide the url of the discovery endpoint in order to use the provider.
{{< highlight csharp >}}

    Plugins.Add(new AuthFeature(() => new AuthUserSession(),
            new IAuthProvider[] {
                    new JsonWebTokenAuthProvider("http://localhost:22530/" + ".well-known/openid-configuration", "http://localhost:22530/resources"),
            }));
{{< /highlight>}}


{{< highlight csharp >}}

    public class JsonWebTokenAuthProvider : AuthProvider, IAuthWithRequest
    {
        private static string Name = "JWT";
        private static string Realm = "/auth/JWT";
        private const string MissingAuthHeader = "Missing Authorization Header";
        private const string InvalidAuthHeader = "Invalid Authorization Header";


        private string Audience { get; }
        private string Issuer { get; }
        private X509Certificate2 Certificate { get; }

        /// <summary>
        /// Creates a new JsonWebToken Auth Provider
        /// </summary>
        /// <param name="discoveryEndpoint">aThe url to get the configuration informaion from.. (er "http://localhost:22530/" + ".well-known/openid-configuration")</param>
        /// <param name="audience">The client for openID (eg js_oidc)</param>

        public JsonWebTokenAuthProvider(string discoveryEndpoint, string audience = null)
        {
            Provider = Name;
            AuthRealm = Realm;
            Audience = audience;
            
            var configurationManager = new ConfigurationManager<OpenIdConnectConfiguration>(discoveryEndpoint);

            var config =  configurationManager.GetConfigurationAsync().Result;

            Certificate = new X509Certificate2(Convert.FromBase64String(config.JsonWebKeySet.Keys.First().X5c.First()));
            Issuer = config.Issuer;
        }

        public override object Authenticate(IServiceBase authService, IAuthSession session, Authenticate request)
        {
            var header = request.oauth_token;
           
            // if no auth header, 401
            if (string.IsNullOrEmpty(header))
            {
                throw HttpError.Unauthorized(MissingAuthHeader);
            }

            var headerData = header.Split(' ');

            // if header is missing bearer portion, 401
            if (string.Compare(headerData[0], "BEARER", StringComparison.OrdinalIgnoreCase) != 0)
            {
                throw HttpError.Unauthorized(InvalidAuthHeader);
            }

            try
            {
               
                // set current principal to the validated token principal
                Thread.CurrentPrincipal = JsonWebToken.ValidateToken(headerData[1], Certificate,  Audience,  Issuer);

                if (HttpContext.Current != null)
                {
                    // set the current request's user the the decoded principal
                    HttpContext.Current.User = Thread.CurrentPrincipal;
                }

                // set the session's username to the logged in user
                session.UserName = Thread.CurrentPrincipal.Identity.Name;

                return OnAuthenticated(authService, session, new AuthTokens(), new Dictionary<string, string>());
            }
            catch (Exception ex)
            {
                throw new HttpError(HttpStatusCode.Unauthorized, ex);
            }
        }

        
        /// <param name="session"></param>
        /// <param name="tokens"></param>
        /// <param name="request"></param>
        /// <returns></returns>
        public override bool IsAuthorized(IAuthSession session, IAuthTokens tokens, Authenticate request = null)
        {
            return HttpContext.Current.User.Identity.IsAuthenticated && session.IsAuthenticated && string.Equals(session.UserName, HttpContext.Current.User.Identity.Name, StringComparison.OrdinalIgnoreCase);
        }

        public void PreAuthenticate(IRequest request, IResponse response)
        {
            var header = request.Headers["Authorization"];
            var authService = request.TryResolve<AuthenticateService>();
            authService.Request = request;

            // pass auth header in as oauth token to authentication
            authService.Post(new Authenticate
            {
                provider = Name,
                oauth_token = header
            });
        }
        
    }   
 {{< /highlight>}}
 
 We use the following class to handle the decoding and validating of the token"
 
{{< highlight csharp >}}
 
    public static class JsonWebToken
    {
        private const string NameClaimType = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name";
        private const string RoleClaimType = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role";
        private const string ActorClaimType = "http://schemas.xmlsoap.org/ws/2009/09/identity/claims/actor";
        private const string StringClaimValueType = "http://www.w3.org/2001/XMLSchema#string";

        public static ClaimsPrincipal ValidateToken(string token, X509Certificate2 certificate, string audience = null, string issuer = null)
        {

            var claims = ValidateIdentityTokenAsync(token, audience, certificate);

            return new ClaimsPrincipal(ClaimsIdentityFromJwt(claims, issuer));
        }



        private static ClaimsIdentity ClaimsIdentityFromJwt(IEnumerable<Claim> claims, string issuer)
        {
            var subject = new ClaimsIdentity("Federation", NameClaimType, RoleClaimType);
            //var claims = ClaimsFromJwt(jwtData, issuer);

            foreach (Claim claim in claims)
            {
                var type = claim.Type;
                if (type == ActorClaimType)
                {
                    if (subject.Actor != null)
                    {
                        throw new InvalidOperationException(string.Format(
                            "Jwt10401: Only a single 'Actor' is supported. Found second claim of type: '{0}', value: '{1}'", new object[] { "actor", claim.Value }));
                    }

                    subject.AddClaim(new Claim(type, claim.Value, claim.ValueType, issuer, issuer, subject));

                    continue;
                }
                if (type == "name")
                {
                    subject.AddClaim(new Claim(NameClaimType, claim.Value, StringClaimValueType, issuer, issuer));
                    continue;
                }
                if (type == "role")
                {
                    subject.AddClaim(new Claim(RoleClaimType, claim.Value, StringClaimValueType, issuer, issuer));
                    continue;
                }
                var newClaim = new Claim(type, claim.Value, claim.ValueType, issuer, issuer, subject);

                foreach (var prop in claim.Properties)
                {
                    newClaim.Properties.Add(prop);
                }

                subject.AddClaim(newClaim);
            }

            return subject;
        }

        private static IEnumerable<Claim> ValidateIdentityTokenAsync(string token, string audience, X509Certificate2 certificate)
        {
            var parameters = new TokenValidationParameters
            {
                ValidAudience = audience,
                ValidIssuer = "http://localhost:22530",
                IssuerSigningToken = new X509SecurityToken(certificate)

            };

            var handler = new JwtSecurityTokenHandler();
            SecurityToken jwt;
            var id = handler.ValidateToken(token, parameters, out jwt);
            
            return id.Claims;
        }
    }
    
{{< /highlight>}}
    
At this point we can use a tool like postman to send authenticated requests to service stack and out provider will correctly authorize the user.  While we are targetting access_tokens you can also validate the id_token if you pass that in instead, although that wouldn't really make a lot of sense unless all you are trying to do is authenticate the user.
    
# Step 3 Angular
For angular we will use the OidcTokenManager library to handle the authentications flows.  All we need to do is hook the library up in a few places and ensure that we are passing the token on all calls to the server.


First we configure OidcTokenManager:

 {{< highlight js >}}
    angular
        .module('app.core')
        .factory('authService', authService);

    /* @ngInject */
    function authService() {

        var config = {
            authority: "http://localhost:22530/",
            client_id: "js_oidc",
            redirect_uri: window.location.protocol + "//" + window.location.host + "/callback.html",
            post_logout_redirect_uri: window.location.protocol + "//" + window.location.host + "/index.html",

            // these two will be done dynamically from the buttons clicked, but are
            // needed if you want to use the silent_renew
            response_type: "id_token token",
            scope: "openid profile email api1 api2",

            // this will toggle if profile endpoint is used
            load_user_profile: true,

            // silent renew will get a new access_token via an iframe 
            // just prior to the old access_token expiring (60 seconds prior)
            silent_redirect_uri: window.location.protocol + "//" + window.location.host + "/silent_renew.html",
            silent_renew: false,

            // this will allow all the OIDC protocol claims to be visible in the window. normally a client app 
            // wouldn't care about them or want them taking up space
            filter_protocol_claims: false
        };

        var mgr = new OidcTokenManager(config);

        return { OidcTokenManager: function() { return mgr; } }

    }
{{< /highlight>}}

Then we create the page that will handle the call back from identity server it will store the token in localStorage.

 {{< highlight html >}}
 
    <!DOCTYPE html>
    <html>
    <head>
        <title></title>
        <meta charset="utf-8" />
    </head>
    <body>
    <script src="/bower_components/oidc-token-manager/dist/oidc-token-manager.js"></script>
    <script>
        var config = {
            authority: "http://localhost:22530/",
            client_id: "js_oidc",
            redirect_uri: window.location.protocol + "//" + window.location.host + "/index.html"
        };
    
        var mgr = new OidcTokenManager(config);
    
        mgr.processTokenCallbackAsync().then(function() {
            window.location = window.location.protocol + "//" + window.location.host;
        },
            function(err) {
                alert("There was a problem getting the Token: " + (error.message || error));
            });
    
    </script>
    </body>
    </html>
 {{< /highlight>}}
 
 Finally we need to make sure that any calls sent to the server have the token added as a authentication header.
  {{< highlight js >}}
    angular
       .module('app.core')
       .factory('oidcInterceptor', oidcInterceptor);
    /* @ngInject */
    function oidcInterceptor(globalConfig, authService) {
        return {
            'request': function (config) {
                if (config.url.indexOf(globalConfig.baseUrl) === 0) {
                    config.headers.Authorization = 'Bearer ' + authService.OidcTokenManager().access_token;
                }
                return config;
            }
        }
    }
{{< /highlight>}}



The full code is available on github.  

