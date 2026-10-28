import json
import re
import time
from playwright.sync_api import sync_playwright

URLS_SEMILLA = [
    "https://www.puntoticket.com/",
    "https://www.puntoticket.com/musica",
    "https://www.puntoticket.com/teatro",
    "https://www.puntoticket.com/deportes"
]

DESCARTE = [
    "precio total incluye cargo",
    "descuentos aplican solo",
    "utilizamos cookies",
    "para más información",
    "layout.",
    "mis datos",
    "compra tu entrada",
    "música\ndeportes",
    "vigencia hasta"
]

def obtener_urls_eventos(page):
    urls_eventos = set()
    print("Buscando eventos en secciones principales...")
    
    for url in URLS_SEMILLA:
        try:
            page.goto(url, wait_until="domcontentloaded", timeout=15000)
            page.wait_for_timeout(1500)
            
            links = page.query_selector_all("a[href*='/evento/']")
            for link in links:
                href = link.get_attribute("href")
                if href:
                    if not href.startswith("http"):
                        href = f"https://www.puntoticket.com{href}"
                    urls_eventos.add(href)
        except Exception as e:
            print(f"Error al cargar {url}: {e}")
            
    return list(urls_eventos)

def extraer_lugar_desde_url(url):
    """Fallback para obtener el recinto limpio directamente del slug de la URL."""
    match = re.search(r'/evento/[^/]+', url)
    if match:
        slug = url.split('/evento/')[-1]
        # Remueve meses y año del final del slug
        slug_limpio = re.sub(r'-(ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic)-\d{4}$', '', slug, flags=re.I)
        partes = slug_limpio.split('-')
        # Si contiene palabras de recintos comunes, retorna el fragmento formateado
        for i, parte in enumerate(partes):
            if parte.lower() in ['teatro', 'estadio', 'movistar', 'arena', 'club', 'centro', 'caupolican', 'fortin']:
                return " ".join(partes[i:]).title()
    return None
 
def extraer_detalle_estructurado(page, url):
    print(f"Procesando: {url}")
    try:
        page.goto(url, wait_until="networkidle", timeout=20000)
        
        # Eliminar navegación, menús y widgets de calendario interactivo para no capturar sus días
        page.evaluate("""() => {
            document.querySelectorAll('nav, header, footer, .menu, .navbar, .calendar, .datepicker, .v-calendar').forEach(el => el.remove());
        }""")
        
        # 1. Título
        titulo = "Sin título"
        h1 = page.query_selector("h1")
        if h1:
            titulo = h1.inner_text().strip()
            
        # 2. Imagen del Afiche
        imagen = None

        # Prioridad A: Clase específica del afiche (la más precisa en PuntoTicket)
        img = page.query_selector("img.img_artist_thumb")

        # Prioridad B: Buscar por sufijos típicos del afiche ('calugalistado' o 'caluga')
        if not img:
            img = page.query_selector("img[src*='calugalistado'], img[src*='caluga']")

        # Prioridad C: Variantes de dominio de CDN descartando mapas/logos conocidos
        if not img:
            img = page.query_selector(
                "img[src*='ptocdn.net/images/eventos/'], "
                "img[src*='ptocdn.net/event-resources/images/']"
            )

        if img:
            imagen = img.get_attribute("src")

        # Limpieza adicional: Si la URL es relativa o incluye parámetros de versión (?v=...)
        if imagen:
            imagen = imagen.strip()

# 3. Fecha y hora
        fecha_hora = None

        # Prioridad A: Buscar etiquetas semánticas <time> (caso PuntoTicket moderno)
        elementos_time = page.query_selector_all("time")
        if elementos_time:
            textos_time = [t.inner_text().strip() for t in elementos_time if t.inner_text().strip()]
            if textos_time:
                fecha_hora = " - ".join(textos_time)

        # Prioridad B: Selectores de clase tradicionales
        if not fecha_hora:
            elementos_fecha = page.query_selector_all(".date, .fecha, span[class*='date'], div[class*='date']")
            for elem in elementos_fecha:
                texto = elem.inner_text().strip()
                if texto and not any(d in texto.lower() for d in DESCARTE) and "SELECCIONA" not in texto:
                    fecha_hora = texto
                    break

        # Prioridad C: Búsqueda controlada por patrón regex
        if not fecha_hora:
            # Solo buscamos en elementos terminales para evitar capturar padres con datos mezclados
            bloques = page.query_selector_all("p, span, li, b, strong")
            for b in bloques:
                texto = b.inner_text().strip()
                if re.search(r'(\d{1,2}\s+de\s+[a-z]+|\d{1,2}[-/]\d{1,2}[-/]\d{2,4}|\d{2}:\d{2}\s*hrs)', texto, re.I):
                    if len(texto) < 80 and not any(d in texto.lower() for d in DESCARTE):
                        fecha_hora = texto
                        break

        # Limpieza de fecha y hora
        if fecha_hora:
            fecha_hora = re.sub(r'\s+', ' ', fecha_hora).strip()
            fecha_hora = re.sub(r'^SELECCIONA FUNCIÓN\s*', '', fecha_hora, flags=re.I)
            fecha_hora = re.sub(r'(\s*n\d+)+', '', fecha_hora)


        # 4. Lugar / Recinto
        lugar = None

        # Prioridad A: Enlace a Google Maps
        map_link = page.query_selector("a[href*='maps.app.goo.gl'], a[href*='google.com/maps']")
        if map_link:
            texto_map = map_link.inner_text().strip()
            if texto_map and len(texto_map) < 80:
                lugar = texto_map

        # Prioridad B: Etiqueta semántica <address>
        if not lugar:
            elem_address = page.query_selector("address")
            if elem_address:
                # Extraer únicamente el primer nodo de texto descartando etiquetas hijas como <time>
                lugar_address = elem_address.evaluate("""(node) => {
                    for (let child of node.childNodes) {
                        if (child.nodeType === Node.TEXT_NODE && child.textContent.trim()) {
                            return child.textContent.trim();
                        }
                    }
                    // Respaldo: primera línea antes del primer salto de línea
                    return node.innerText.split('\\n')[0].trim();
                }""")
                if lugar_address and len(lugar_address) < 80 and not any(d in lugar_address.lower() for d in DESCARTE):
                    lugar = lugar_address

        # Prioridad C: Selectores de clase tradicionales
        if not lugar:
            elementos_lugar = page.query_selector_all(".venue, .recinto, .place, span[class*='place'], div[class*='place']")
            for elem in elementos_lugar:
                texto = elem.inner_text().strip()
                if texto and len(texto) < 60 and not any(d in texto.lower() for d in DESCARTE):
                    lugar = texto
                    break

        # Prioridad D: Respaldo por URL
        if not lugar:
            lugar = extraer_lugar_desde_url(url)

        # Limpieza final del lugar
        if lugar:
            lugar = re.sub(r'\s+', ' ', lugar).strip()



        # 5. Descripción limpia
        parrafos = page.query_selector_all("p, div.description p, div.event-detail p")
        texto_descripcion = []
        
        for p in parrafos:
            texto = p.inner_text().strip()
            if texto and len(texto) > 15:
                texto_lower = texto.lower()
                if not any(frase in texto_lower for frase in DESCARTE):
                    if texto not in texto_descripcion and texto != fecha_hora and texto != lugar:
                        texto_descripcion.append(texto)

        return {
            "url": url,
            "titulo": titulo,
            "imagen": imagen,
            "fecha_hora": fecha_hora if fecha_hora else None,
            "lugar": lugar,
            "descripcion": "\n".join(texto_descripcion[:5])
        }
    except Exception as e:
        print(f"Error procesando {url}: {e}")
        return None

def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        )
        page = context.new_page()
        
        urls = obtener_urls_eventos(page)
        print(f"\nTotal de eventos encontrados: {len(urls)}")
        
        resultados = []
        for url in urls:
            datos = extraer_detalle_estructurado(page, url)
            if datos:
                resultados.append(datos)
            time.sleep(1)
            
        browser.close()
        
        with open("eventos_puntoticket_perfecto.json", "w", encoding="utf-8") as f:
            json.dump(resultados, f, ensure_ascii=False, indent=4)
            
        print("\n✅ Proceso completado. Revisa 'eventos_puntoticket_perfecto.json'.")

if __name__ == "__main__":
    main()