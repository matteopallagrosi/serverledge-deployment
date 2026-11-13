import sys, os, csv
import pandas as pd
import matplotlib.pyplot as plt

def load_data(directory):
    history_file = os.path.join(directory, "locust-results_stats_history.csv")
    df_history = pd.read_csv(history_file)
    
    txt_file = os.path.join(directory, "response_times.txt")
    rows = []
    with open(txt_file, "r") as f:
        reader = csv.reader(f, delimiter=";")
        for row in reader:
            if len(row) < 5: continue
            status = int(row[0].strip())
            resp_time = float(row[1].strip())
            url = row[2].strip().split("/")[-1]
            regions_str = row[3].strip()
            
            completions = []
            for token in regions_str.split("|"):
                if ":" in token:
                    func, region = token.split(":", 1)
                    completions.append((func.strip(), region.strip()))
                    
            rows.append({
                "status": status, 
                "response_time": resp_time, 
                "workflow": url, 
                "completions": completions
            })
    return df_history, pd.DataFrame(rows)

def plot_throughput_vs_time(df_history, out_dir):
    plt.figure(figsize=(10, 5))
    
    df_agg = df_history[df_history["Name"] == "Aggregated"].copy()
    
    df_agg["Timestamp"] = df_agg["Timestamp"] - df_agg["Timestamp"].min()
    
    plt.plot(df_agg["Timestamp"], df_agg["Requests/s"], label="Throughput", color='b')
    plt.xlabel("Elapsed Time (s)")
    plt.ylabel("Requests / sec")
    plt.title("Throughput vs Time")
    plt.grid(True)
    plt.savefig(os.path.join(out_dir, "throughput_vs_time.pdf"))
    plt.close()

def plot_goodput_vs_time(df_history, out_dir):
    plt.figure(figsize=(10, 5))

    df_agg = df_history[df_history["Name"] == "Aggregated"].copy()

    df_agg["Timestamp"] = df_agg["Timestamp"] - df_agg["Timestamp"].min()

    df_agg["Goodput"] = df_agg["Requests/s"] - df_agg["Failures/s"]

    df_agg["Goodput"] = df_agg["Goodput"].clip(lower=0)

    plt.plot(df_agg["Timestamp"], df_agg["Goodput"], label="Successful Requests", color='green')

    plt.xlabel("Elapsed Time (s)")
    plt.ylabel("Successful Requests / sec")
    plt.title("Goodput vs Time")
    plt.legend()
    plt.grid(True)
    plt.savefig(os.path.join(out_dir, "goodput_vs_time.pdf"))
    plt.close()

def plot_failures_vs_time(df_history, out_dir):
    plt.figure(figsize=(10, 5))

    df_agg = df_history[df_history["Name"] == "Aggregated"].copy()

    df_agg["Timestamp"] = df_agg["Timestamp"] - df_agg["Timestamp"].min()

    plt.plot(df_agg["Timestamp"], df_agg["Failures/s"], label="Failures", color='red')

    plt.xlabel("Elapsed Time (s)")
    plt.ylabel("Failures / sec")
    plt.title("Failures vs Time")
    plt.legend()
    plt.grid(True)
    plt.savefig(os.path.join(out_dir, "failures_vs_time.pdf"))
    plt.close()

def plot_boxplot(df, out_dir):
    success_df = df[df["status"] == 200]
    workflows = success_df["workflow"].unique()

    data = [success_df[success_df["workflow"] == w]["response_time"].values for w in workflows]

    plt.figure(figsize=(8, 6))

    plt.boxplot(data, labels=workflows, patch_artist=True, showfliers=False)

    plt.ylabel("Response Time (ms)")
    plt.grid(axis='y', linestyle='--', linewidth=0.5)

    plt.title("Workflow Response Times (Zoomed - No Outliers)")
    plt.savefig(os.path.join(out_dir, "boxplot_response_times.pdf"))
    plt.close()

def plot_edge_cloud_bar(df, out_dir):
    records = []
    for _, row in df.iterrows():
        for func, region in row["completions"]:
            records.append({"workflow": row["workflow"], "function": func, "region": region})
    
    comp_df = pd.DataFrame(records)
    if comp_df.empty: return
    
    comp_df['is_edge'] = comp_df['region'] == 'ROME'
    summary = comp_df.groupby(['workflow', 'is_edge']).size().unstack(fill_value=0)
    
    summary.columns = summary.columns.astype(str)
    
    summary = summary.rename(columns={"True": "Edge", "False": "Cloud"})
    
    for col in ["Edge", "Cloud"]:
        if col not in summary.columns:
            summary[col] = 0
            
    summary = summary[["Edge", "Cloud"]]
    
    summary_pct = summary.div(summary.sum(axis=1), axis=0) * 100
    
    summary_pct.plot(kind='bar', stacked=True, figsize=(8, 6), color={"Edge": "#2ecc71", "Cloud": "#3498db"})
    
    plt.ylabel("Percentage of Tasks (%)")
    plt.title("Task Execution: Edge vs Cloud")
    plt.xticks(rotation=0)
    plt.legend(loc='upper right')
    
    plt.savefig(os.path.join(out_dir, "edge_vs_cloud_percentage.pdf"))
    plt.close()

if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: python analyze.py <results_directory>")
    
    results_dir = sys.argv[1]
    df_hist, df_resp = load_data(results_dir)
    
    plot_throughput_vs_time(df_hist, results_dir)
    plot_goodput_vs_time(df_hist, results_dir)
    plot_failures_vs_time(df_hist, results_dir)

    plot_boxplot(df_resp, results_dir)
    plot_edge_cloud_bar(df_resp, results_dir)
    print(f"Grafici generati con successo in: {results_dir}")
