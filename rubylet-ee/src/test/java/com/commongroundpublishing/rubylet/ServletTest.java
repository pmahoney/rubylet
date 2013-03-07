package com.commongroundpublishing.rubylet;

import static junitx.framework.StringAssert.assertContains;
import static junitx.framework.StringAssert.assertNotContains;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import java.io.File;
import java.io.IOException;
import java.net.MalformedURLException;

import junitx.framework.StringAssert;

import org.apache.commons.io.FileUtils;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.servlet.ServletContextHandler;
import org.eclipse.jetty.servlet.ServletHolder;
import org.jruby.embed.LocalContextScope;
import org.jruby.embed.ScriptingContainer;
import org.junit.After;
import org.junit.Before;
import org.junit.BeforeClass;
import org.junit.Test;

import com.gargoylesoftware.htmlunit.FailingHttpStatusCodeException;
import com.gargoylesoftware.htmlunit.WebClient;
import com.gargoylesoftware.htmlunit.html.HtmlElement;
import com.gargoylesoftware.htmlunit.html.HtmlPage;

public class ServletTest {
    
    private static String abs(String file) {
        return (new File(file)).getAbsolutePath();
    }
    
    private static final String JRUBY_HOME = abs("target/jruby/META-INF/jruby.home");

    private static final String APP_ROOT_RAILS_3_0_12 = abs("target/test-classes/rails-3.0.12");

    private static final String APP_ROOT_SINATRA_1_3_2 = abs("target/test-classes/sinatra-1.3.2");

    private static final String[] APP_ROOTS = new String[] {
        APP_ROOT_RAILS_3_0_12,
        APP_ROOT_SINATRA_1_3_2,
    };
    
    public static abstract class ContainerAction {
        
        public ScriptingContainer container;
        
        public Object run(String script) {
            return container.runScriptlet(script);
        }
        
        public void call(ScriptingContainer container) {
            this.container = container;
            call();
        }
        
        public abstract void call();
        
    }
    
    public static void withContainer(ContainerAction action) {
        ScriptingContainer container = new ScriptingContainer(LocalContextScope.THREADSAFE);
        try {
            container.setHomeDirectory(JRUBY_HOME);
            container.runScriptlet("require 'rubygems'");
            action.call(container);
        } finally {
            container.terminate();
        }
    }
    
    @BeforeClass
    public static void bundleInstall() {
        withContainer(new ContainerAction() {
            
            public void gem(String cmnd) {
                Object args = run("'" + cmnd + "'.split.map{|s|\"'#{s}'\"}.join(',')");
                run("Gem::GemRunner.new.run [" + args + "]");
            }

            public void call() {
                run("require 'rubygems/gem_runner'");
                gem("install " +
                     "--conservative " +
                     "--clear-sources --source http://rubygems.org/ " +
                     "jruby-openssl");
                gem("install --conservative bundler");
            }
            
        });
        
        for (final String appRoot : APP_ROOTS) {
            withContainer(new ContainerAction() {
                public void call() {
                    container.setCurrentDirectory(appRoot);
                    run("require 'bundler'");
                    run("require 'bundler/cli'");
                    run("Bundler::CLI.start ['install']");
                }
            });
        }
    }
    
    private static final int PORT = 8017;
    
    private Server server;
    
    private ServletContextHandler context;
    
    private WebClient webClient;


    @Before
    public void startJetty() throws Exception {
        server = new Server(PORT);
        
        context = new ServletContextHandler(ServletContextHandler.SESSIONS);
        context.setContextPath("/");
        server.setHandler(context);

        context.addEventListener(new ExternalJRubyLoader());
        //context.addEventListener(new Runtime());
        
        // should be done in each test after finishing servlet config:
        // server.start();
    }
    
    @After
    public void stopJetty() throws Exception {
        server.stop();
    }

    @Before
    public void makeWebClient() {
        webClient = new WebClient();
        webClient.setThrowExceptionOnFailingStatusCode(false);
        webClient.setThrowExceptionOnScriptError(false);
        webClient.setPrintContentOnFailingStatusCode(false);
        webClient.setCssEnabled(false);
        webClient.setJavaScriptEnabled(false);
    }

    @After
    public void stopWebClient() {
        webClient.closeAllWindows();
    }
    
    protected ServletHolder addServlet(String appRoot, String pathSpec) throws Exception {
        final ServletHolder holder = new ServletHolder(new RestartableServlet());
        //final ServletHolder holder = new ServletHolder(new PlainServlet());
        
        holder.setInitParameter("rubylet.jrubyHome", JRUBY_HOME);
        holder.setInitParameter("rubylet.appRoot", appRoot);
        holder.setInitParameter("rubylet.bundleExec", "true");

        context.setInitParameter("rubylet.jrubyHome", JRUBY_HOME);
        context.setInitParameter("rubylet.appRoot", appRoot);
        context.setInitParameter("rubylet.bundleExec", "true");
        context.setInitParameter("rubylet.env.RAILS_ENV", "production");

        context.addServlet(holder, pathSpec);

        return holder;
    }

    /**
     * Register or start a servlet at /* into the ServletRunner.
     * 
     * @param appRoot
     * @throws Exception
     */
    protected ServletHolder addServlet(String appRoot) throws Exception {
        return addServlet(appRoot, "/*");
    }
    
    protected HtmlPage get(String uri) throws FailingHttpStatusCodeException, MalformedURLException, IOException {
        final HtmlPage page = webClient.getPage("http://localhost:" + PORT + uri);
        if (page.getWebResponse().getStatusCode() >= 500) {
            System.err.println(page.asText());
            throw new RuntimeException(page.getWebResponse().getStatusMessage());
        }
        return page;
    }
    
    /**
     * Like Thread.sleep but ignore just return if interrupted.
     * 
     * @param millis time to sleep in milliseconds
     * @see {@link Thread#sleep(long)}
     */
    public static void sleep(long millis) {
        try {
            Thread.sleep(millis);
        } catch (InterruptedException e) {
            // ignore
        }
    }
    
    private void assertScriptsSrcsStartWith(String path, HtmlPage page) {
        for (HtmlElement elem : page.getElementsByTagName("script")) {
            StringAssert.assertStartsWith(path,  elem.getAttribute("src"));
        }
    }

    private void assertStylesHrefsStartWith(String path, HtmlPage page) {
        for (HtmlElement elem : page.getElementsByTagName("link")) {
            StringAssert.assertStartsWith(path,  elem.getAttribute("href"));
        }
    }

    @Test
    public void runsRailsApp() throws Exception {
        addServlet(APP_ROOT_RAILS_3_0_12);
        server.start();
    
        final HtmlPage page = get("/");
        
        assertEquals(200, page.getWebResponse().getStatusCode());
        assertEquals("Rails3012", page.getTitleText());
        assertContains("Hello, world!", page.asText());
        
        assertScriptsSrcsStartWith("/", page);
        assertStylesHrefsStartWith("/", page);
    }
    
    /**
     * Just a simple object so our test listener can register
     * that it did certain things. 
     */
    public static final class Status {
       public boolean started = false;
       public boolean stopped = false;
    }

    // @Test
    public void runsRailsAppWithListener() throws Exception {
        addServlet(APP_ROOT_RAILS_3_0_12);
        context.addEventListener(new Runtime());
        context.addEventListener(new RestartableListener.A());
        context.setInitParameter("RubyListener.A.require", "./lib/test_listener");
        context.setInitParameter("RubyListener.A.rubyClass", "TestListener");
        
        final Status status = new Status();
        
        final String name = "test_status";
        context.setAttribute(name, status);
        
        assertFalse(status.started);
        server.start();
        assertTrue(status.started);
        
        final HtmlPage page = get("/");
        
        assertEquals(200, page.getWebResponse().getStatusCode());
        assertEquals("Rails3012", page.getTitleText());
        assertContains("Hello, world!", page.asText());
        
        server.stop();
        sleep(200);
        assertTrue(status.stopped);
    }

    @Test
    public void restartsRailsApp() throws Exception {
        final String appRoot = APP_ROOT_RAILS_3_0_12; 
        addServlet(appRoot);
        server.start();

        {
            final HtmlPage page = get("/");
            
            assertEquals(200, page.getWebResponse().getStatusCode());
            assertContains("Hello, world!", page.asText());
            assertNotContains("restarted", page.asText());
       }
        
        final File welcomeDir = new File(appRoot, "app/views/welcome");
        final File currentIndex = new File(welcomeDir, "index.html.erb");
        final File origIndex = new File(welcomeDir, "index.html.erb.orig");
        final File newIndex = new File(welcomeDir, "index2.html.erb");
        
        final File restartFile = new File(appRoot, "tmp/restart.txt");

        FileUtils.copyFile(currentIndex, origIndex);
        try {
            // put the new index file in place, touch restart.txt
            FileUtils.copyFile(newIndex, currentIndex);
            FileUtils.touch(restartFile);
            
            // perform request to trigger reload
            HtmlPage page = get("/");
            long timeoutAt = System.currentTimeMillis() + 60000;
            while (System.currentTimeMillis() < timeoutAt) {
                sleep(200);
                
                if (System.currentTimeMillis() > timeoutAt) {
                    fail("app did not restart with 60s");
                }
                
                // this request should eventually be against the reloaded app
                page = get("/");
                assertEquals(200, page.getWebResponse().getStatusCode());
                if (page.asText().contains("restarted")) {
                    break;
                }
            }

            assertEquals(200, page.getWebResponse().getStatusCode());
            assertContains("Hello, world!", page.asText());
            assertContains("restarted", page.asText());
        } finally {
            FileUtils.deleteQuietly(currentIndex);
            FileUtils.moveFile(origIndex, currentIndex);
        }
        
    }
    
    @Test
    public void runsRailsAppAtAltContext() throws Exception {
        context.setContextPath("/rails");
        addServlet(APP_ROOT_RAILS_3_0_12, "/*");
        server.start();

        final HtmlPage page = get("/rails/");
        
        assertEquals(200, page.getWebResponse().getStatusCode());
        assertContains("Hello, world!", page.asText());
        assertEquals("http://localhost:" + PORT + "/rails/",
                     page.getAnchorByText("Root").getHrefAttribute());
        assertEquals("/rails/photos",
                     page.getAnchorByText("Photos").getHrefAttribute());
        
        assertScriptsSrcsStartWith("/rails/", page);
        assertStylesHrefsStartWith("/rails/", page);
    }

    @Test
    public void runsRailsAtSubPath() throws Exception {
        ServletHolder holder = addServlet(APP_ROOT_RAILS_3_0_12, "/subpath/*");
        holder.setInitParameter("rubylet.servletPath", "/subpath");
        server.start();
        
        {
            final HtmlPage page = get("/");
            assertEquals(404, page.getWebResponse().getStatusCode());
        }


        {
            final HtmlPage page = get("/subpath/");
            
            assertEquals(200, page.getWebResponse().getStatusCode());
            assertContains("Hello, world!", page.asText());
            assertEquals("http://localhost:" + PORT + "/subpath/",
                    page.getAnchorByText("Root").getHrefAttribute());
            assertEquals("/subpath/photos",
                page.getAnchorByText("Photos").getHrefAttribute());
            
            assertScriptsSrcsStartWith("/subpath/", page);
            assertStylesHrefsStartWith("/subpath/", page);
        }
    }

    @Test
    public void runsRailsAtAltContextAndSubPath() throws Exception {
        context.setContextPath("/context");
        ServletHolder holder = addServlet(APP_ROOT_RAILS_3_0_12, "/subpath/*");
        holder.setInitParameter("rubylet.servletPath", "/subpath");
        server.start();
        
        {
            final HtmlPage page = get("/");
            assertEquals(404, page.getWebResponse().getStatusCode());
        }

        {
            final HtmlPage page = get("/context");
            assertEquals(404, page.getWebResponse().getStatusCode());
        }

        {
            final HtmlPage page = get("/context/subpath/");
            
            assertEquals(200, page.getWebResponse().getStatusCode());
            assertContains("Hello, world!", page.asText());
            assertEquals("http://localhost:" + PORT + "/context/subpath/",
                    page.getAnchorByText("Root").getHrefAttribute());
            assertEquals("/context/subpath/photos",
                page.getAnchorByText("Photos").getHrefAttribute());
            
            assertScriptsSrcsStartWith("/context/subpath/", page);
            assertStylesHrefsStartWith("/context/subpath/", page);
        }
    }
    
    @Test
    public void runsSinatraApp() throws Exception {
        addServlet(APP_ROOT_SINATRA_1_3_2, "/*");
        server.start();
        
        final HtmlPage page = get("/hi");
        
        assertEquals(200, page.getWebResponse().getStatusCode());
        assertContains("Hello, world!", page.asText());
        assertContains("from Sinatra", page.asText());
    }

    @Test
    public void runsSinatraAppAtAltContext() throws Exception {
        context.setContextPath("/sinatra");
        addServlet(APP_ROOT_SINATRA_1_3_2, "/*");
        server.start();

        final HtmlPage page = get("/sinatra/hi");
        
        assertEquals(200, page.getWebResponse().getStatusCode());
        assertContains("Hello, world!", page.asText());
        assertContains("from Sinatra", page.asText());
    }

    @Test
    public void runsSinatraAppAtSubpath() throws Exception {
        addServlet(APP_ROOT_SINATRA_1_3_2, "/subpath/*");
        server.start();

        final HtmlPage page = get("/subpath/hi");
        
        assertEquals(200, page.getWebResponse().getStatusCode());
        assertContains("Hello, world!", page.asText());
        assertContains("from Sinatra", page.asText());
    }

    @Test
    public void runsSinatraAppAtAltContextAndSubpath() throws Exception {
        context.setContextPath("/sinatra");
        addServlet(APP_ROOT_SINATRA_1_3_2, "/subpath/*");
        server.start();

        final HtmlPage page = get("/sinatra/subpath/hi");
        
        assertEquals(200, page.getWebResponse().getStatusCode());
        assertContains("Hello, world!", page.asText());
        assertContains("from Sinatra", page.asText());
    }
    
    @Test
    public void restartsSinatraAppManyTimes() throws Exception {
        final String appRoot = APP_ROOT_SINATRA_1_3_2;
        addServlet(appRoot, "/*");
        server.start();

        final HtmlPage firstPage = get("/started_at");
        
        String startedAt;
        
        assertEquals(200, firstPage.getWebResponse().getStatusCode());
        startedAt = firstPage.asText();
        
        final long timeout = 30000; // 30 s
        final File restartFile = new File(appRoot, "tmp/restart.txt");

        for (int i = 0; i < 20; ++i) {
            // touch restart.txt; but make sure the timestamp changed!
            // (sometimes it doesn't... not sure why)
            final long mod = restartFile.lastModified();
            while (restartFile.lastModified() == mod) {
                FileUtils.touch(restartFile);
            }
        
            // wait until it restarts by testing if /started_at (timestamp) has changed
            final long startTime = System.currentTimeMillis();
            for (;;) {
                final HtmlPage page = get("/started_at");
                assertEquals(200, page.getWebResponse().getStatusCode());
                if (!page.asText().equals(startedAt)) {
                    startedAt = page.asText();
                    break;
                }

                final long elapsed = System.currentTimeMillis() - startTime;
                
                assertTrue("restart timed out", timeout > elapsed);
                
                sleep(100);
            }
        }
    }

}
