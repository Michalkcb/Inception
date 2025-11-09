<?php
/* Front page template */
get_header();
?>

<main>
	<div class="container">
		<section id="services" class="section">
			<div class="section-title">
				<h2>Nasze usługi</h2>
				<small style="color:var(--muted)">Bezpieczeństwo • Komfort • Doświadczenie</small>
			</div>
			<div class="grid">
				<div class="card fade-in">
					<div class="icon" aria-hidden="true">
						<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path d="M4 20c0-5 8-9 8-9s-2-4-2-7 6 0 6 0v16H4z"/></svg>
					</div>
					<h3>Pełen czarter</h3>
					<p>Wynajmij cały jacht z załogą lub bez — dopasujemy jednostkę do Twoich potrzeb.</p>
				</div>
				<div class="card fade-in">
					<div class="icon" aria-hidden="true">
						<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path d="M12 7v6l4 2"/></svg>
					</div>
					<h3>Wynajem na godziny</h3>
					<p>Szybkie rejsy dzienne i prywatne wycieczki — idealne na eventy i rodzinne wypady.</p>
				</div>
				<div class="card fade-in">
					<div class="icon" aria-hidden="true">
						<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path d="M12 2C8 2 5 5 5 9c0 5 7 11 7 11s7-6 7-11c0-4-3-7-7-7z"/></svg>
					</div>
					<h3>Szczególne trasy</h3>
					<p>Spersonalizowane trasy, skipper, kucharz na pokładzie i usługi concierge.</p>
				</div>
			</div>
		</section>

		<section id="fleet" style="margin-top:2.5rem">
			<div class="section-title">
				<h2>Nasza flota</h2>
				<small style="color:var(--muted)">Od komfortowych katamaranów po sportowe jachty</small>
			</div>
			<div class="grid">
				<div class="card fleet-card fade-in">
					<img src="https://images.unsplash.com/photo-1504151932400-72d4384f04b3?auto=format&fit=crop&w=1200&q=60" alt="Catamaran">
					<h3>Lagoon 450 - Katamaran</h3>
					<p>Przestronne wnętrza, idealny dla grup do 10 osób.</p>
				</div>
				<div class="card fleet-card fade-in">
					<img src="https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=60" alt="Sailing yacht">
					<h3>Bavaria Cruiser 46</h3>
					<p>Wygodny, elegancki jacht kabinowy dla rodzin i przyjaciół.</p>
				</div>
				<div class="card fleet-card fade-in">
					<img src="https://images.unsplash.com/photo-1505691723518-36a8f3d0f1d6?auto=format&fit=crop&w=1200&q=60" alt="Speed boat">
					<h3>Speed Cruiser</h3>
					<p>Szybka jednostka na krótkie, dynamiczne trasy i transfery.</p>
				</div>
			</div>
		</section>

		<section id="contact" style="margin-top:2.5rem">
			<div class="section-title">
				<h2>Kontakt i rezerwacje</h2>
				<small style="color:var(--muted)">Szybka rezerwacja i wsparcie 24/7</small>
			</div>
			<div class="grid">
				<div class="card">
					<h3>Zarezerwuj rejs</h3>
					<p>Wyślij zapytanie, podając daty oraz preferencje — oddzwonimy w ciągu 24h.</p>
					<p><strong>Email:</strong> contact@aegeanyachts.example</p>
					<p><strong>Telefon:</strong> +30 210 000 0000</p>
					<a class="cta" href="mailto:contact@aegeanyachts.example">Wyślij zapytanie</a>
				</div>
				<div class="card">
					<h3>Biuro</h3>
					<p>Port: Marina Zea, Pireus, Ateny — odbiory i zwroty jachtów dostępne codziennie.</p>
					<p><small style="color:var(--muted)">Godziny: 08:00 - 20:00</small></p>
				</div>
			</div>
		</section>
	</div>
</main>

<?php
get_footer();
?>
