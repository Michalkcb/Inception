<!doctype html>
<html <?php language_attributes(); ?>>
<head>
	<meta charset="<?php bloginfo( 'charset' ); ?>">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title><?php wp_title( '|', true, 'right' ); bloginfo( 'name' ); ?></title>
	<?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
<header class="site-header">
	<div class="nav">
		<div style="display:flex;align-items:center;gap:1rem">
			<div class="brand"><a href="<?php echo esc_url( home_url( '/' ) ); ?>"><?php bloginfo( 'name' ); ?></a></div>
			<div style="background:rgba(255,255,255,0.08);padding:.25rem .6rem;border-radius:6px;font-size:.9rem;color:#d6f6f5">Static site (bonus) — mbany</div>
		</div>
		<nav>
			<?php
				wp_nav_menu( array(
					'theme_location' => 'primary',
					'container' => false,
					'menu_class' => 'main-menu',
					'fallback_cb' => false,
				) );
			?>
		</nav>
	</div>

		<div class="hero">
			<div class="container">
				<h1>Odkryj Greckie archipelagi na własnym jachcie</h1>
				<p>Organizujemy czartery jachtów w Morzu Egejskim — krótkie rejsy, tygodniowe wyprawy i indywidualne trasy. Luksusowa flota, doświadczona załoga i pełne wsparcie.</p>
				<a class="cta" href="#contact">Zarezerwuj rejs</a>
			</div>
		</div>
	</header>

<?php
