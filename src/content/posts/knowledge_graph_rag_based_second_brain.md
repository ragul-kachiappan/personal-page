+++
title = "Building a Second Brain for Organizations: An Experiment with Knowledge Graphs and GraphRAG"
date = 2025-12-25T10:00:00+05:30
tags = ["AI/ML", "Knowledge Graphs", "RAG", "Neo4j", "GenAI"]
categories = ["AI/ML", "Data Engineering"]
+++

Apps like Notion and Obsidian market themselves as a "second brain" for individuals—a place where you can dump everything you know, connect ideas through links, and have instant access to your accumulated knowledge. Obsidian even visualizes your notes as a graph, revealing connections you never knew existed.

But what about organizations?

Company knowledge lives in a different kind of chaos: Slack threads, Jira tickets, Salesforce records, HR systems, meeting transcripts, project updates, email chains. This information exists across 10-15 different systems, owned by different teams, formatted differently, and rarely talking to each other. When an executive asks "What are our top organizational risks right now?" or "What's the impact if we lose our senior platform engineer?", someone has to spend days manually piecing together information from disparate sources.

Traditional BI tools can aggregate metrics, but they fundamentally miss something: *relationships*. An organization isn't just a collection of data points—it's a network of people, projects, clients, and dependencies. Who reports to whom? Which projects depend on which other projects? Who's the critical connector between the engineering and sales teams? These relationships encode knowledge that tabular data simply cannot capture.

This got me thinking: what if we could build a "second brain" at the organizational level? A knowledge graph that captures not just the data, but the *structure* of how everything connects—and then use modern RAG techniques with LLMs to make it queryable in natural language?

So I built one as an experiment for my internal company presentation. Here's what I learned.

> **📂 Source Code**: The complete implementation is available on GitHub: [company-second-brain](https://github.com/ragul-kachiappan/company-second-brain.git)

---

## The Idea: Knowledge Graphs Meet RAG

Search engines like Google have used knowledge graphs for years. When you search for "Albert Einstein," Google doesn't just find web pages containing those words—it understands that Einstein is an entity with relationships: physicist, born in Germany, developed relativity, worked at Princeton. This structural understanding enables far richer answers than pure text matching.

The insight I wanted to explore: **what if we applied the same approach to organizational data?**

Traditional RAG (Retrieval-Augmented Generation) works well for document-based questions. You embed your documents, find similar chunks via vector search, and feed them to an LLM for synthesis. But RAG treats documents as isolated islands of text. It doesn't understand that the person mentioned in a Slack message is the same person in the HR system, or that the project in this Jira ticket depends on another project that's currently at risk.

GraphRAG changes this by:

1. **Modeling entities and relationships explicitly** — People, projects, divisions, and clients become nodes; their connections become edges
2. **Embedding content within graph context** — Text chunks are linked to their source entities, enabling retrieval that understands organizational structure
3. **Enabling multi-hop reasoning** — Questions like "Who reports to Sarah, and what are they working on?" require traversing relationships, not just finding similar text

The combination of graph structure + vector embeddings + LLM synthesis creates something genuinely more powerful than any single approach.

---

## The Experiment: TechScale Inc.

To test this idea, I created a fictional company called **TechScale Inc.**—a 500-employee technology company with:

- **4 divisions**: GenAI, Platform, Mobile, Security
- **18 employees** modeled in detail with roles, skills, managers, and project allocations
- **Multiple projects** with budgets, health scores, dependencies, and team assignments
- **Daily updates** capturing the kind of unstructured knowledge that lives in real organizations

Each entity has both structured metadata (role, budget, health score) and unstructured content (daily updates, meeting notes, strategic observations). Here's what a person record looks like:

```yaml
---
id: P-005
type: Person
name: David Kim
role: VP Engineering
skills: [Leadership, Architecture, Scaling, Strategic Planning]
office: Seoul
manager_id: null
member_of_division_id: DIV-PLATFORM
works_on:
  - { project_id: PRJ-PLATFORM-MODERNIZATION, allocation_fte: 0.3, role: "Executive Sponsor" }
  - { project_id: PRJ-SECURITY-INITIATIVE, allocation_fte: 0.2, role: "Sponsor" }
cost_rate_usd_per_day: 1200
---

### Bio
Engineering leader responsible for platform strategy and cross-division technical initiatives.

### Daily updates
- 2025-08-10: Board presentation on technical debt—$3.2M budget approved.
- 2025-08-11: Escalation meeting with Priya and Sarah on infrastructure bottlenecks.
- 2025-08-12: Strategic planning session—evaluating acquisition of ML infrastructure company.
- 2025-08-13: Crisis response: Coordinated emergency fix for InsightPilot outage.
- 2025-08-14: Talent planning: Approved hiring 4 platform engineers to reduce Sarah's bus factor.
```

The combination of structured properties (who they report to, what projects they're on, their allocation) with unstructured daily updates creates a rich knowledge base that mirrors real organizational data.

---

## Architecture: Four Modes of Understanding

Not all questions are created equal. "Who reports to Priya?" is fundamentally different from "What are the top organizational risks across our projects?" The first needs local entity traversal; the second requires organization-wide pattern analysis.

I implemented an **LLM-powered query classifier** that routes queries to different retrieval strategies:

```bash
┌───────────────────────────────────────────────────────────────────────────┐
│                           Executive Query                                  │
└───────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                      LLM Query Classification                              │
│   • Analyze intent and complexity                                          │
│   • Route to appropriate search strategy                                   │
│   • Provide confidence scoring                                             │
└───────────────────────────────────────────────────────────────────────────┘
                                    │
          ┌─────────────┬───────────┼───────────┬─────────────┐
          │             │                       │             │
          ▼             ▼                       ▼             ▼
    ┌──────────┐  ┌──────────┐           ┌──────────┐  ┌──────────┐
    │  LOCAL   │  │  GLOBAL  │           │RELATION- │  │ TEMPORAL │
    │  Search  │  │  Search  │           │   SHIP   │  │  Search  │
    └──────────┘  └──────────┘           └──────────┘  └──────────┘
          │             │                       │             │
          ▼             ▼                       ▼             ▼
    Entity-focused  Org-wide risk        Impact analysis  Time-based
    neighborhood    & utilization        & dependency     trends &
    analysis        patterns             mapping          drift detection
```

### 1. Local Search: Entity-Focused Analysis

For questions about specific people, projects, or divisions, local search performs **multi-hop neighborhood analysis**. It identifies the target entity, traverses its relationships (1-hop for direct connections, 2-hop for extended network), aggregates relevant content, and synthesizes insights.

**Example query**: *"Who reports to Priya Raman and what are they working on?"*

The system:

1. Identifies "Priya Raman" as the target entity
2. Traverses `REPORTS_TO` relationships to find direct reports
3. For each report, traverses `WORKS_ON` relationships to find projects
4. Collects daily updates and project details for context
5. Synthesizes a coherent answer

This multi-hop capability is something traditional vector search simply cannot do—it requires understanding graph structure.

### 2. Global Search: Organization-Wide Intelligence

For strategic questions that span the entire organization, global search runs graph algorithms to identify patterns:

- **Single Points of Failure**: People with high centrality who, if lost, would severely impact multiple projects
- **Resource Utilization**: Over-allocated vs. under-utilized team members
- **Project Risk Assessment**: At-risk projects and their downstream dependencies
- **Division Health**: Aggregated metrics across organizational units

**Example query**: *"What are the top organizational risks across our projects right now?"*

The response identifies that David Kim (VP Engineering) is involved in four critical projects and represents a significant single point of failure—losing him would jeopardize multiple initiatives. This insight emerges from analyzing the graph structure, not from any single document.

### 3. Relationship Search: Connection Analysis

Some questions focus specifically on connections and dependencies:

- Impact of personnel changes on projects
- Collaboration patterns between teams
- Critical path analysis for project dependencies
- Cross-divisional relationship mapping

**Example query**: *"What would be the impact of losing our senior engineers?"*

This traverses the graph to find all projects, relationships, and downstream dependencies connected to senior engineering personnel, then synthesizes the organizational impact.

### 4. Temporal Search: Change Over Time

The fourth mode (partially implemented) analyzes how things change over time—burnout trends, project health evolution, satisfaction shifts. This is the "drift search" concept from Microsoft's GraphRAG research, tracking how patterns evolve rather than just their current state.

---

## The Technical Stack

The implementation uses:

- **Neo4j**: Graph database storing entities and relationships
- **Vector Embeddings**: `nomic-embed-text` for semantic content search
- **Ollama**: Local LLM inference for classification and synthesis
- **neo4j-graphrag**: Official Python library providing various retriever patterns

The core engine orchestrates everything:

```python
class ExecutiveGraphRAG:
    def __init__(self, ...):
        # Initialize retrievers for different strategies
        self.vector_retriever = VectorRetriever(...)
        self.text2cypher_retriever = Text2CypherRetriever(...)
        self.vector_cypher_retriever = VectorCypherRetriever(...)
        self.global_search_retriever = GlobalSearchRetriever(...)
        self.enhanced_local_retriever = EnhancedLocalSearchRetriever(...)
        self.relationship_search_retriever = RelationshipSearchRetriever(...)

        # LLM-based query classifier
        self.llm_classifier = LLMQueryClassifier(...)

    async def process_executive_query(self, query: str):
        # 1. Classify query intent
        search_mode, complexity, confidence = self.llm_classifier.classify_query(query)

        # 2. Route to appropriate retriever
        strategy = self.llm_classifier.get_retriever_strategy(search_mode, complexity)
        relevant_docs = await self._retrieve_with_strategy(query, strategy)

        # 3. Build adaptive prompt based on query type
        prompt = self._build_adaptive_prompt(query, context, query_type, search_mode)

        # 4. Stream synthesized response
        async for chunk in self.ollama_client.chat(...):
            yield chunk
```

The query classifier uses the LLM itself to understand query intent:

```python
def classify_query(self, query: str) -> Tuple[SearchMode, QueryComplexity, float]:
    classification_prompt = f"""
    Classify this query into the most appropriate search mode and complexity:

    SEARCH MODES:
    - LOCAL: Focus on specific entities and their immediate relationships
    - GLOBAL: Organization-wide analysis and strategic insights
    - RELATIONSHIP: Connection and impact analysis
    - TEMPORAL: Time-based trends and changes

    EXECUTIVE QUERY: "{query}"

    Respond with JSON: {{"search_mode": "...", "complexity": "...", "confidence": 0.85}}
    """
    # Parse response and return classification
```

This LLM-in-the-loop classification is more robust than regex patterns—it understands nuance and can reason about query intent.

---

## The Graph Schema

The knowledge graph models organizational structure:

```bash
┌──────────────────────────────────────────────────────────────────┐
│                      Knowledge Graph Schema                      │
└──────────────────────────────────────────────────────────────────┘

    ┌─────────┐         REPORTS_TO          ┌─────────┐
    │ Person  │ ◄─────────────────────────► │ Person  │
    └─────────┘                             └─────────┘
         │                                        │
         │ MEMBER_OF                              │ WORKS_ON
         ▼                                        ▼
    ┌──────────┐       BELONGS_TO           ┌─────────┐
    │ Division │ ◄────────────────────────  │ Project │
    └──────────┘                            └─────────┘
         │                                        │
         │ LED_BY                                 │ DEPENDS_ON
         ▼                                        ▼
    ┌─────────┐                             ┌─────────┐
    │ Person  │                             │ Project │
    └─────────┘                             └─────────┘

Each entity has:
  - Structured properties (id, name, role, budget, health_score, etc.)
  - Linked TextChunks with embedded content (daily updates, notes)
```

The `TextChunk` nodes are where vector search happens—semantic content linked back to their source entities. This means a vector search hit can immediately traverse to related organizational context.

---

## What I Learned

### Where GraphRAG Shines

1. **Questions about relationships**: "Who depends on whom?", "What's the impact of X?", "How are teams connected?" These are fundamentally graph questions.

2. **Aggregation across structure**: "Which divisions are over-utilized?", "What are organization-wide risks?" require traversing and aggregating across the graph.

3. **Multi-hop reasoning**: "What projects would be affected if David Kim leaves?" requires understanding his connections, then the connections of his connections.

4. **Historical record navigation**: A newspaper company querying decades of archives about related topics would benefit enormously—the graph captures relationships between topics, people, events, and sources that pure text search misses.

### The Honest Caveat: 95% Don't Need This

Let me be direct: **for most use cases, you don't need a knowledge graph**.

If your questions are primarily:

- Searching through documents for relevant passages
- Looking up specific facts in a database
- Generating content from a corpus

...then traditional RAG or even a well-structured relational database will serve you well. Knowledge graphs add complexity, require careful schema design, and introduce additional infrastructure.

GraphRAG becomes valuable when:

- Your data is inherently networked (people, projects, dependencies)
- Relationships are first-class citizens in your queries
- You need to reason about impact, influence, and connection patterns
- Simple retrieval isn't enough—you need structural understanding

### The Data Engineering Challenge

The hardest part isn't the retrieval—it's keeping the graph synchronized with reality. In a real deployment:

- How do you ingest updates from 15 different source systems?
- How do you handle entity resolution (is "Sarah Chen" in Slack the same as "S. Chen" in Jira)?
- How do you manage schema evolution as organizational structure changes?
- How do you ensure data freshness without overwhelming compute resources?

Change Data Capture (CDC), entity resolution pipelines, and synchronization logic are arguably harder problems than the GraphRAG retrieval itself. This experiment focused on retrieval; a production system would need substantial data engineering investment.

### Running on Modest Hardware

One pleasant surprise: this works reasonably well on modest hardware. I ran the entire system locally with an 8B parameter model (not even a state-of-the-art model), and it produced surprisingly coherent insights. The graph structure compensates for some limitations of smaller models—you're feeding it pre-structured, relevant context rather than asking it to find needles in haystacks.

---

## Beyond This Experiment

This was a proof-of-concept, but the pattern has broader applications:

**Research Organizations**: A pharmaceutical company could model research papers, scientists, compounds, and clinical trials as a graph. "What research is connected to protein X?" becomes a graph traversal augmented with semantic search.

**Media Companies**: A newspaper could model articles, journalists, topics, sources, and events. "What have we written about related to company Y's CEO?" traverses relationships rather than keyword-matching.

**Legal Firms**: Cases, precedents, judges, arguments, and outcomes form a natural graph. "Find relevant precedents that might apply to this case" benefits from both semantic similarity and structural relationships.

**Enterprise Knowledge Management**: The original premise—organizations themselves as knowledge graphs. Meeting transcripts linked to attendees linked to projects linked to clients linked to outcomes.

The common thread: **domains where relationships matter as much as content**.

---

## Conclusion

This experiment convinced me that the combination of knowledge graphs + vector search + LLM synthesis is genuinely more capable than any single approach for certain classes of problems. The graph provides structure; vectors provide semantic understanding; LLMs provide synthesis and natural language interface.

Is it worth the complexity? For most applications, probably not. But for domains with rich, interconnected data where relationships carry meaning—organizational intelligence, research discovery, legal analysis, media archives—GraphRAG offers capabilities that simpler approaches cannot match.

The "second brain for organizations" framing captures the aspiration: a system that doesn't just store information but *understands* how everything connects, enabling the kind of questions that previously required human institutional knowledge to answer.

Whether this particular approach gains traction remains to be seen. But the underlying insight—that structure and semantics together are more powerful than either alone—feels durable. As LLMs continue improving and graph databases become more accessible, I expect we'll see more systems that blend these paradigms.

---

## References

- [Microsoft GraphRAG Paper](https://arxiv.org/abs/2404.16130) - The research that inspired this approach
- [Neo4j GraphRAG Python Library](https://neo4j.com/docs/neo4j-graphrag-python/current/) - Official library for GraphRAG patterns
- [Obsidian](https://obsidian.md/) - The "second brain" app that inspired the organizational analogy
- [Knowledge Graphs in Search Engines](https://en.wikipedia.org/wiki/Knowledge_Graph) - How Google uses graphs for search
