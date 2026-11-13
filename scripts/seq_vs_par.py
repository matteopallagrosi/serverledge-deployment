import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import matplotlib.ticker as ticker

def load_data(filename, mode_name):
    records = []
    try:
        with open(filename, 'r') as f:
            for line in f:
                parts = line.strip().split(';')
                if len(parts) >= 3 and parts[0].strip() == '200':
                    rt_ms = float(parts[1].strip()) * 1000
                    wf = parts[2].strip()

                    if wf == 'detection':
                        wf = 'car_detection'

                    records.append({
                        'Workflow': wf,
                        'Tempo di Risposta (ms)': rt_ms,
                        'Esecuzione': mode_name
                    })
    except FileNotFoundError:
        print(f"Errore: File {filename} non trovato.")
    return records

data_seq = load_data('response_times_seq.txt', 'Sequenziale')
data_par = load_data('response_times_par.txt', 'Parallela')

df = pd.DataFrame(data_seq + data_par)

if not df.empty:
    plt.figure(figsize=(10, 6))

    ax = sns.boxplot(
        data=df,
        x='Workflow',
        y='Tempo di Risposta (ms)',
        hue='Esecuzione',
        palette='Set2',
        showfliers=False
    )

    ax.yaxis.set_major_locator(ticker.MultipleLocator(5000))
    ax.yaxis.set_minor_locator(ticker.MultipleLocator(1000))

    plt.title('Distribuzione dei Tempi di Risposta: Sequenziale vs Parallela (Senza Outliers)', fontsize=14)
    plt.ylabel('Tempo di Risposta (millisecondi)', fontsize=12)
    plt.xlabel('Workflow', fontsize=12)

    plt.grid(axis='y', which='major', linestyle='-', alpha=0.7)
    plt.grid(axis='y', which='minor', linestyle=':', alpha=0.4)

    plt.tight_layout()
    plt.savefig('boxplot_tempi_risposta_ms_dettagliato.png', dpi=300)
    plt.show()
