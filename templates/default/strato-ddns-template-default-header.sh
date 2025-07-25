<header class="bg-primary text-white" x-data="{ mobileMenuOpen: false }">
    <nav class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div class="flex h-16 items-center justify-between">
            <div class="flex items-center">
                <a href="{{ url_for('index') }}" class="text-xl font-bold">Strato DDNS</a>
                <div class="hidden md:ml-6 md:block">
                    <div class="flex space-x-4">
                        {% if session.logged_in %}
                        <a href="{{ url_for('log_page') }}" class="px-3 py-2 text-sm font-medium">Protokoll</a>
                        <a href="{{ url_for('config_page') }}" class="px-3 py-2 text-sm font-medium">Konfiguration</a>
                        {% endif %}
                    </div>
                </div>
            </div>
            <div class="hidden md:block">
                {% if session.logged_in %}
                <a href="{{ url_for('logout') }}" class="px-3 py-2 text-sm font-medium">Logout</a>
                {% endif %}
            </div>
            <div class="-mr-2 flex md:hidden">
                <!-- Mobile menu button -->
                <button @click="mobileMenuOpen = !mobileMenuOpen" type="button" class="inline-flex items-center justify-center rounded-md p-2 text-white hover:bg-primary-darker focus:outline-none focus:ring-2 focus:ring-inset focus:ring-white" aria-controls="mobile-menu" aria-expanded="false">
                    <span class="sr-only">Hauptmenü öffnen</span>
                    <svg x-show="!mobileMenuOpen" class="block h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5" /></svg>
                    <svg x-show="mobileMenuOpen" x-cloak class="h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
                </button>
            </div>
        </div>
    </nav>

    <!-- Mobile menu, show/hide based on menu state. -->
    <div class="md:hidden" id="mobile-menu" x-show="mobileMenuOpen" x-cloak>
        <div class="space-y-1 px-2 pt-2 pb-3">
            {% if session.logged_in %}
            <a href="{{ url_for('log_page') }}" class="block rounded-md px-3 py-2 text-base font-medium">Protokoll</a>
            <a href="{{ url_for('config_page') }}" class="block rounded-md px-3 py-2 text-base font-medium">Konfiguration</a>
            <a href="{{ url_for('logout') }}" class="block rounded-md px-3 py-2 text-base font-medium">Logout</a>
            {% endif %}
        </div>
    </div>
</header>
