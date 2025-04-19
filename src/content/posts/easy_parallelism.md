+++
title = 'How I Slashed a 1 million Email processing Pipeline from 11 Days to 38 Hours with Lightweight Parallelism'
date = 2025-04-18T16:48:50+05:30
tags = ["concurrency", "parallel computing", "Generative AI"]
categories = ["data engineering", "concurrency"]
+++

In the era of Generative AI, the quality and scale of data processing have become more critical than ever. While sophisticated language models and ML algorithms steal the spotlight, the behind-the-scenes work of data preparation remains the unsung hero of successful AI implementations. From cleaning inconsistent formats to transforming raw inputs into structured information, these preparatory steps directly impact model performance and output quality. However, as data volumes grow exponentially, traditional sequential processing approaches quickly become bottlenecks, turning what should be one-time tasks into resource-intensive operations that delay model training and deployment. For organizations working with moderate to large datasets—too small to justify a full Hadoop or Spark implementation, yet too unwieldy for single-threaded processing—finding the middle ground of efficient parallelism has become essential for maintaining agile AI development cycles.

## Task at Hand

In the technical products sales domain, we faced a classic challenge: building a RAG-based GenAI chatbot capable of answering technical queries by leveraging historical customer service email conversations. Our analysis showed that approximately 65% of customer inquiries were repetitive in nature, making this an ideal candidate for automation through a modern GenAI solution.

The foundation of any effective AI system is high-quality data, and in our case, this meant processing a substantial volume of historical email conversations between customers and technical experts. As is often the case with real-world AI implementations, data preparation emerged as the most challenging aspect of the entire process.

Our email data resided in two distinct sources:

1. **MSG file dumps**: These are Microsoft Outlook's proprietary email storage format files (with .msg extension), which encapsulate not just the email text but also formatting, attachments, and metadata in a binary structure. Our archive contained hundreds of thousands of these files spanning several years of customer communications.

2. **Outlook inbox threads**: These were ongoing conversation threads stored directly in dedicated customer service Outlook inboxes, which provided more recent interactions organized by conversation topic.

Together, these sources comprised approximately 1 million email threads with a total data footprint of around 400GB. The sheer volume made even simple operations time-consuming when approached sequentially.

Our data preparation task involved multiple steps:

- Extracting plain text and relevant attachments from the proprietary formats
- Implementing basic pre-processing to filter out irrelevant emails based on certain patterns
- Removing spam and promotional content that had made it through to the service inboxes
- Applying email-specific cleaning to make conversation threads cohesive
- Preserving the relationship between emails and their relevant attachments
- Loading the processed data into a database in a structured format suitable for retrieval

The end goal was to transform this raw, unstructured data into a clean, structured corpus that could serve as the knowledge base for our RAG (Retrieval-Augmented Generation) system. With properly processed data, the chatbot would be able to retrieve relevant historical conversations and generate accurate, contextually appropriate responses to customer inquiries.

Let's examine the data processing implementation we initially developed to handle these email sources.

## Data Processing Pipeline

Our approach to processing the email data required handling two distinct sources through separate workflows, as illustrated below:

![Email Processing Pipeline](/images/email_processing_flowchart.png)

### Data Sources

We needed to process emails from two primary sources:

- **Historical Archives**: Email threads stored as .msg files in network storage
- **Active Communications**: Ongoing conversations in Outlook inboxes

### Solution Architecture

To handle these diverse sources efficiently, we developed two parallel processing flows:

### Flow 1: MSG files processing

#### Step 1: MSG to EML Conversion

Since msg format is proprietary to Microsoft, we couldn't directly load it in a python script for content extraction. The parsers in scripting languages weren't good enough. Then we found a linux cli tool popular for this purpose [msgconvert](https://www.matijs.net/software/msgconv/) which can convert msg files into an open format eml files.

Example usage:

```bash
msgconvert /path/to/msg_file.msg --outfile /path/to/eml_file.eml

```

#### Step 2: EML Parsing

Here's a high level code snippet for sequential eml parsing, cleaning and save to db:

```python
#!/usr/bin/env python3
import os
from pathlib import Path
import argparse
from tqdm import tqdm


def process_single_email(file_path):
    """
    Process a single email file
    - Parse the email
    - Extract relevant data
    - Transform content as needed
    """
    # Implementation details abstracted away
    email_data = parse_email_file(file_path)
    if email_data:
        return transform_email_data(email_data)
    return None


def parse_email_file(file_path):
    """Parse an email file and return structured data"""
    # Implementation details abstracted away
    return {...}  # Email data dictionary


def transform_email_data(email_data):
    """Process and transform email data"""
    # Implementation details abstracted away
    return {...}  # Processed email data


def save_to_database(processed_data):
    """Save processed email data to database"""
    # Implementation details abstracted away
    pass


def main():
    # Parse command-line arguments
    parser = argparse.ArgumentParser(
        description="Process email files sequentially"
    )
    parser.add_argument(
        "--dir",
        type=Path,
        default=Path.cwd(),
        help="Directory with email files",
    )
    parser.add_argument("--db-name", default="emails", help="Database name")
    args = parser.parse_args()

    # Get list of email files
    email_files = list(args.dir.glob("*.eml"))

    # Initialize database connection
    db = initialize_database(args.db_name)

    # Process emails sequentially with progress bar
    results = []
    for file_path in tqdm(email_files, desc="Processing emails"):
        processed_data = process_single_email(file_path)
        if processed_data:
            results.append(processed_data)

    # Save all results to database
    save_to_database(results)

    print(f"Processed {len(results)} emails and saved to {args.db_name}")


if __name__ == "__main__":
    main()
```

The above script shows a traditional sequential approach to processing email files:

1. It collects all EML files from a directory
2. Processes them one by one in a single thread
3. Saves the results to a database

This approach is straightforward but can be slow when dealing with many files, as each file must be fully processed before moving to the next one.

### Flow 2: Outlook emails processing

#### Step 1: Extract Outlook Emails via PowerShell

Outlook provides programmatic access and APIs via powershell and many other languages. We felt powershell is well suited and integrated for this purpose given the complexity of navigating through Microsoft ecosystem.
Here's the Outlook APIs [documentation](https://learn.microsoft.com/en-us/outlook/rest/reference) for reference.

```powershell
# High-level script for extracting emails from Outlook folders and saving to SQLite

# Configuration
$DatabasePath = "C:\path\to\emails.db"
$FolderName = "Inbox"

function Initialize-Database {
    param ($dbPath)

    # Load SQLite assembly and create connection
    # Implementation details abstracted away

    # Return the connection object
    return $connection
}

function Process-SingleEmail {
    param ($emailItem, $dbConnection)

    # Extract email properties
    $subject = $emailItem.Subject
    $body = $emailItem.Body
    $htmlBody = $emailItem.HTMLBody
    $receivedDate = $emailItem.ReceivedTime

    # Save to database
    Save-EmailToDatabase -emailData @{
        Subject = $subject
        Body = $body
        HtmlBody = $htmlBody
        ReceivedDate = $receivedDate
    } -attachments $emailItem.Attachments -dbConnection $dbConnection

    # Return success
    return $true
}

function Save-EmailToDatabase {
    param ($emailData, $attachments, $dbConnection)

    # Save email data to database
    # Implementation details abstracted away

    # Save attachments
    foreach ($attachment in $attachments) {
        # Save attachment to database
        # Implementation details abstracted away
    }
}

function Main {
    # Initialize Outlook
    $outlook = New-Object -ComObject Outlook.Application
    $namespace = $outlook.GetNamespace("MAPI")

    # Connect to database
    $dbConnection = Initialize-Database -dbPath $DatabasePath

    # Get the target folder
    $folder = $namespace.Folders.Item(1).Folders.Item($FolderName)

    # Get all items
    $totalItems = $folder.Items.Count
    Write-Host "Found $totalItems emails to process"

    # Process each email sequentially
    $processedCount = 0
    $startTime = Get-Date

    foreach ($item in $folder.Items) {
        if ($item -is [Microsoft.Office.Interop.Outlook.MailItem]) {
            Process-SingleEmail -emailItem $item -dbConnection $dbConnection
            $processedCount++

            # Show progress
            Write-Progress -Activity "Processing Emails" -Status "Processing email $processedCount of $totalItems" -PercentComplete (($processedCount / $totalItems) * 100)
        }
    }

    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds

    # Close connection
    $dbConnection.Close()

    # Print summary
    Write-Host "Completed processing $processedCount emails in $duration seconds"
    Write-Host "Processing speed: $([math]::Round($processedCount / $duration, 2)) emails/second"
}
# Run the main function
Main
```

The above script follows a straightforward approach:

1. Connects to both Outlook and a SQLite database
2. Retrieves all emails from a specified folder
3. Processes each email one by one in a single thread
4. Extracts email content and attachments
5. Saves data to the database for each email before moving to the next

This approach is simple to implement but can be slow for processing large mailboxes as it handles each email sequentially.

#### Step 2: Data Cleaning with Python

After extracting the raw email data from Outlook, we process it through a Python cleaning script similar to the one used for EML parsing. This script handles common email-specific cleaning tasks including:

- Normalizing inconsistent text encodings
- Filtering out auto-generated messages and spam
- Sanitizing HTML content
- Extracting plain text from formatted emails
- Reconstructing conversation threads based on headers

This sequential cleaning process faces the same performance limitations as our earlier EML parsing approach, with each email being processed one at a time.

## The Bottleneck: Inefficiencies in Sequential Processing

Sequential processing creates significant bottlenecks when handling large datasets. In our case with approximately 1 million emails, the limitations become quickly apparent.

### Time Constraints and Business Impact

With each email taking 1-2 seconds to process sequentially, our complete dataset would require:

- ~277 hours (11.5 days) at best
- ~555 hours (23 days) at worst

This timeline creates several critical problems:

- **Stalled Prototyping**: Development cycles grind to a halt when each iteration takes days or weeks.
- **Missed MVP Deadlines**: Time-sensitive projects become impossible to deliver.
- **Technological Obsolescence**: In the rapidly evolving Gen AI space, six months can render approaches obsolete. By the time sequential processing completes, your solution risks being outdated before deployment.

### Finding the Right Solution Scale

The traditional answer to big data processing involves systems like:

- Apache Spark
- Hadoop
- MapReduce

However, these enterprise-scale solutions introduce unnecessary complexity and cost for our scale. While powerful, they're designed for petabyte-scale operations across distributed infrastructure—overkill for our million-email dataset.

Concurrency and parallel computing are expansive fields, but we don't need their full complexity. We're looking for middle ground—more efficient than sequential processing but simpler than distributed big data frameworks.

### The Independence Advantage

Our sequential pipeline has a key characteristic perfect for parallelization: each file processes independently of others. This independence means we can parallelize each step without compromising data integrity.

Fortunately, Linux, Python, and PowerShell all provide robust parallelism tools tailored to different use cases. We'll now explore how these accessible approaches can dramatically reduce processing time without the overhead of enterprise distributed systems.

## Parallel Implementations

After identifying the bottlenecks in sequential processing, let's explore three practical parallel implementations across different platforms. Each provides a straightforward approach to parallelism without the complexity of enterprise-scale distributed systems.

### 1. Linux - GNU Parallel

[GNU Parallel](https://www.gnu.org/software/parallel/) is a shell tool designed to execute jobs in parallel. It's particularly powerful for batch processing files in a Unix/Linux environment.

GNU Parallel takes a simple command that would normally run on a single file and automatically distributes it across multiple CPU cores. It handles the job distribution, monitoring, and output collection, making parallelism accessible without complex coding.

```bash
find "/src_path/to/msg_files" -name "*.msg" | parallel -j 8 msgconvert {} --outfile "/dest_path/to/eml_files"/{/.}.eml
```

In this example:

- The `find` command locates all `.msg` files
- `parallel` executes the conversion command (`msgconvert`) on 8 files simultaneously (`-j 8`)
- `{}` represents each input file path
- `{/.}` represents the filename without extension

This simple one-liner can reduce processing time by a factor roughly equal to the number of CPU cores available. On an 8-core system, we might see a 6-7x speedup (accounting for some overhead), reducing a 12-day job to less than 2 days without any complex coding.

### 2. Python - Multiprocessing

Python's [multiprocessing](https://docs.python.org/3/library/multiprocessing.html) library provides a robust way to utilize multiple cores for parallel processing. Unlike threading in Python (limited by the Global Interpreter Lock), multiprocessing creates separate processes that can truly run in parallel.

```python
#!/usr/bin/env python3
import os
from pathlib import Path
import argparse
from multiprocessing import Pool
from tqdm import tqdm
import time


def process_single_email(file_path):
    """
    Process a single email file
    - Parse the email
    - Extract relevant data
    - Transform content as needed
    """
    # Implementation details abstracted away
    email_data = parse_email_file(file_path)
    if email_data:
        return transform_email_data(email_data)
    return None


def parse_email_file(file_path):
    """Parse an email file and return structured data"""
    # Implementation details abstracted away
    return {...}  # Email data dictionary


def transform_email_data(email_data):
    """Process and transform email data"""
    # Implementation details abstracted away
    return {...}  # Processed email data


def save_to_database(processed_data):
    """Save processed email data to database"""
    # Implementation details abstracted away
    pass


def main():
    # Parse command-line arguments
    parser = argparse.ArgumentParser(
        description="Process email files in parallel"
    )
    parser.add_argument(
        "--dir",
        type=Path,
        default=Path.cwd(),
        help="Directory with email files",
    )
    parser.add_argument("--db-name", default="emails", help="Database name")
    parser.add_argument(
        "--jobs", type=int, default=4, help="Number of parallel processes"
    )
    args = parser.parse_args()

    # Get list of email files
    email_files = list(args.dir.glob("*.eml"))

    # Initialize database connection
    db = initialize_database(args.db_name)

    # Start timing
    start_time = time.time()

    # Process emails in parallel
    with Pool(processes=args.jobs) as pool:
        # Map the function to all files and collect results
        # tqdm wraps the iterator to show a progress bar
        results = list(
            tqdm(
                pool.imap(process_single_email, email_files),
                total=len(email_files),
                desc=f"Processing emails with {args.jobs} workers",
            )
        )

    # Filter out None results
    results = [r for r in results if r]

    # Calculate processing time
    processing_time = time.time() - start_time

    # Save all results to database
    save_to_database(results)

    print(f"Processed {len(results)} emails in {processing_time:.2f} seconds")
    print(
        f"Processing speed: {len(results)/processing_time:.2f} emails/second"
    )


if __name__ == "__main__":
    main()
```

The key parallel components in this Python script:

1. **Pool of Workers**: `Pool(processes=args.jobs)` creates a pool of worker processes (configurable via command line)
2. **Work Distribution**: `pool.imap()` distributes email files across workers efficiently
3. **Progress Tracking**: `tqdm` provides a visual progress bar during execution
4. **Result Collection**: Results from all processes are collected before database storage
5. **Performance Metrics**: The script calculates and displays processing speed

Unlike the sequential approach where each email would be processed and immediately saved to the database one-by-one, this parallel implementation:

- Processes multiple emails simultaneously
- Collects all results in memory
- Performs a single batch database operation

On an 8-core system, this typically yields a 5-7x speedup over sequential processing, with the bonus of built-in progress tracking and performance metrics.

### 3. PowerShell - Runspace Pools

PowerShell offers several parallelism options, with [Runspace Pools](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.runspacepool?view=powershellsdk-7.4.0) being particularly effective for I/O-bound operations like email processing.

```powershell
# Parallel Outlook Email Processing
# High-level script for extracting emails from Outlook folders and saving to SQLite using parallel processing

# Configuration
$DatabasePath = "C:\path\to\emails.db"
$FolderName = "Inbox"
$MaxJobs = 4  # Number of parallel jobs

function Initialize-Database {
    param ($dbPath)

    # Load SQLite assembly and create connection
    # Implementation details abstracted away

    # Return the connection object
    return $connection
}

function Process-SingleEmail {
    param ($emailItem)

    # Extract email properties
    $subject = $emailItem.Subject
    $body = $emailItem.Body
    $htmlBody = $emailItem.HTMLBody
    $receivedDate = $emailItem.ReceivedTime

    # Process attachments if any
    $attachmentData = @()
    foreach ($attachment in $emailItem.Attachments) {
        $attachmentData += @{
            Name = $attachment.FileName
            Data = $attachment.PropertyAccessor.GetProperty("http://schemas.microsoft.com/mapi/proptag/0x37010102")
        }
    }

    # Return processed data (will be saved to DB later)
    return @{
        Subject = $subject
        Body = $body
        HtmlBody = $htmlBody
        ReceivedDate = $receivedDate
        Attachments = $attachmentData
    }
}

function Save-EmailBatchToDatabase {
    param ($emailBatch, $dbConnection)

    # Begin transaction for better performance
    $transaction = $dbConnection.BeginTransaction()

    foreach ($emailData in $emailBatch) {
        # Save email to database
        # Implementation details abstracted away

        # Save attachments if any
        foreach ($attachment in $emailData.Attachments) {
            # Save attachment to database
            # Implementation details abstracted away
        }
    }

    # Commit transaction
    $transaction.Commit()
}

function Main {
    # Initialize Outlook
    $outlook = New-Object -ComObject Outlook.Application
    $namespace = $outlook.GetNamespace("MAPI")

    # Connect to database
    $dbConnection = Initialize-Database -dbPath $DatabasePath

    # Get the target folder
    $folder = $namespace.Folders.Item(1).Folders.Item($FolderName)

    # Get all items
    $allItems = @()
    foreach ($item in $folder.Items) {
        if ($item -is [Microsoft.Office.Interop.Outlook.MailItem]) {
            $allItems += $item
        }
    }

    $totalItems = $allItems.Count
    Write-Host "Found $totalItems emails to process"

    # Process emails in parallel
    $startTime = Get-Date

    # Create a throttle limit for jobs
    $throttleLimit = $MaxJobs

    # Create runspace pool
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, $throttleLimit)
    $runspacePool.Open()

    # Create job tracking collections
    $jobs = @()
    $results = @()

    # Create script block for parallel processing
    $scriptBlock = {
        param ($emailItem)
        Process-SingleEmail -emailItem $emailItem
    }

    # Start parallel jobs
    foreach ($item in $allItems) {
        $powerShell = [powershell]::Create().AddScript($scriptBlock).AddParameter("emailItem", $item)
        $powerShell.RunspacePool = $runspacePool

        $jobs += @{
            PowerShell = $powerShell
            Handle = $powerShell.BeginInvoke()
        }
    }

    # Track progress
    $completed = 0
    while ($jobs.Handle.IsCompleted -contains $false) {
        $completedJobs = $jobs | Where-Object { $_.Handle.IsCompleted -eq $true }

        foreach ($job in $completedJobs) {
            if ($job.PowerShell.EndInvoke($job.Handle)) {
                $results += $job.PowerShell.EndInvoke($job.Handle)
                $completed++

                # Show progress
                Write-Progress -Activity "Processing Emails in Parallel" -Status "Processed $completed of $totalItems" -PercentComplete (($completed / $totalItems) * 100)
            }

            # Clean up resources
            $job.PowerShell.Dispose()
            $jobs.Remove($job)
        }

        # Small sleep to prevent CPU spinning
        Start-Sleep -Milliseconds 100
    }

    # Process any remaining jobs
    foreach ($job in $jobs) {
        $results += $job.PowerShell.EndInvoke($job.Handle)
        $job.PowerShell.Dispose()
    }

    # Save all results to database in batches
    $batchSize = 100
    for ($i = 0; $i -lt $results.Count; $i += $batchSize) {
        $batch = $results[$i..([Math]::Min($i + $batchSize - 1, $results.Count - 1))]
        Save-EmailBatchToDatabase -emailBatch $batch -dbConnection $dbConnection
    }

    # Calculate processing time
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds

    # Close resources
    $runspacePool.Close()
    $runspacePool.Dispose()
    $dbConnection.Close()

    # Print summary
    Write-Host "Completed processing $totalItems emails in $duration seconds"
    Write-Host "Processing speed: $([math]::Round($totalItems / $duration, 2)) emails/second"
    Write-Host "Using $MaxJobs parallel jobs"
}

# Run the main function
Main
```

The PowerShell parallelism implementation offers several key advantages over the sequential approach:

1. **Runspace Pool**: Creates a managed pool of PowerShell environments with controlled concurrency
2. **Asynchronous Execution**: Uses `BeginInvoke()` to start jobs without blocking
3. **Job Management**: Tracks and collects completed jobs while new ones continue processing
4. **Batch Database Operations**: Uses transactions to efficiently commit multiple records at once
5. **Resource Management**: Properly disposes of resources to prevent memory leaks

This approach separates the extraction phase from the storage phase, allowing each to be optimized independently. By processing multiple emails concurrently and then saving in efficient batches, we achieve both parallelism benefits and database optimization.

On a typical workstation, this parallel PowerShell approach can yield a 4-6x performance improvement over sequential processing for Outlook extraction tasks, turning a multi-week project into a few days of processing.

## Benchmarks

To demonstrate the real-world impact of parallel processing, we conducted benchmarks using GNU Parallel with the msgconvert tool across varying workloads and parallelism levels.

### Performance Scaling

The benchmark results clearly illustrate how parallel processing transforms the performance curve:

![Benchmark results for msgconvert process under various parallel conditions](/images/line_chart_benchmark.png)

As shown in the graph, the performance gains follow Amdahl's Law, where:

- Single process performance (blue line) scales linearly with input size, reaching ~450 seconds for 5000 files
- Adding parallel jobs dramatically reduces processing time
- The improvement follows a diminishing returns pattern as we increase parallelism

The most significant observations:

- **2 parallel jobs** cut processing time roughly in half
- **4 parallel jobs** reduced time to approximately 25% of single-process performance
- **8 parallel jobs** achieved nearly 6x speedup
- **16-64 parallel jobs** showed continued but diminishing improvements

### Hardware Constraints and Efficiency Limits

The benchmark reveals an important practical consideration: hardware limitations establish an upper bound on parallelism benefits. Note how the lines for 32 and 64 parallel jobs nearly overlap, indicating we've reached the parallelization ceiling for this workload on the test hardware.

This plateau occurs due to several factors:

- **CPU core count**: Once jobs exceed available cores, performance gains diminish
- **I/O bottlenecks**: As parallel processes compete for disk access
- **Memory constraints**: Available RAM must be shared across all processes
- **Scheduling overhead**: Managing many processes introduces its own overhead

### Cross-Platform Consistency

While these benchmarks specifically measure GNU Parallel performance, similar scaling patterns emerge when using Python's multiprocessing library and PowerShell's RunspacePool. The fundamental performance characteristics—initial linear scaling followed by diminishing returns—remain consistent across all three implementations, though the exact efficiency curve varies based on implementation details.

For optimal performance across any platform, these results suggest configuring parallelism to match your hardware capabilities—typically setting job count to match or slightly exceed your CPU core count provides the best balance of performance gain versus resource consumption.

## Takeaways

Our journey through parallel processing implementations reveals crucial lessons for AI practitioners working with real-world data:

- **Start simple but scale smartly**: Begin with accessible parallelization tools before investing in complex distributed systems—the speedup from basic parallel processing often provides sufficient performance gains for million-scale datasets.

- **Hardware-aware optimization**: Configure parallelism to match your hardware capabilities—typically matching job count to available CPU cores provides the optimal balance between performance and resource consumption.

- **Separate processing from storage**: Structure workflows to process data in parallel but save in efficient batches using transactions, addressing both computation and I/O bottlenecks.

- **Language-agnostic principles**: Whether using GNU Parallel, Python's multiprocessing, or PowerShell's RunspacePools, the fundamental scaling patterns remain consistent, allowing cross-platform implementation.

In the age of Generative AI, where model quality depends directly on data quality, these parallelization techniques serve as the unsung heroes of AI development pipelines. By reducing data processing time from weeks to days, they enable faster iteration cycles, more experimental approaches, and ultimately better AI solutions—keeping pace with the rapidly evolving GenAI landscape without requiring enterprise-scale infrastructure investments.

## References

- [GNU Parallel](https://www.gnu.org/software/parallel/)
- [Multiprocessing in Python](https://docs.python.org/3/library/multiprocessing.html)
- [Powershell runspace pools](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.runspacepool?view=powershellsdk-7.4.0)
- [Getting started guide in runspace pools](https://www.criticaldesign.net/post/leveraging-powershell-runspaces)
- [Example guide on GNU parallel](https://edbennett.github.io/high-performance-python/04-gnu-parallel/index.html)
- [Example guide on Python multiprocessing and concurrency](https://superfastpython.com/multiprocessing-pool-python/)
- [SuperFast Python - Comprehensive guide on Python concurrency](https://superfastpython.com/)
- [Outlook API documentation](https://learn.microsoft.com/en-us/outlook/rest/reference)
